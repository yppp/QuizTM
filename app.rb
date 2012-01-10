# cofing:utf-8
require 'sinatra'
require 'oauth'
require 'twitter'
require 'haml'
require './key' unless ENV['KEY']
require 'sass'
require 'pp'
require './model/quiz'
require 'compass' 

configure do
  use Rack::Session::Cookie,
  secret: SecureRandom.hex(32)

  Compass.configuration do |config|
    config.project_path = File.dirname(__FILE__)
    config.sass_dir = 'views'
  end

  set :haml, { :format => :html5 }
  set :scss, Compass.sass_engine_options

end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end


before do
  if session[:access_token]
    Twitter.configure do |config|
      config.consumer_key = ENV['KEY']
      config.consumer_secret = ENV['SECRET']
      config.oauth_token = session[:access_token]
      config.oauth_token_secret = session[:access_token_secret]
    end

    @twitter = Twitter::Client::new
  else
    @twitter = nil
  end
end

def base_url
  default_port = (request.scheme == "http") ? 80 : 443
  port = (request.port == default_port) ? "" : ":#{request.port.to_s}"
  "#{request.scheme}://#{request.host}#{port}"
end


def oauth_consumer
  OAuth::Consumer.new(ENV['KEY'], ENV['SECRET'], :site => "http://twitter.com")
end

get '/:name.css' do
  scss :"#{params[:name]}"
end

get '/' do
  @quiz = Quiz.all
  haml :index
end

get '/tw/:qid' do
  @quiz = Quiz.find(id: params[:qid])
  @twitter.update("#{@quiz.sentence} / QuizTwitMaker http://quiztm.heroku.com/quiz/#{@quiz.id}")
  redirect '/'
end

get '/quiz/:parm' do
  @quiz = Quiz.find(id: params[:parm].to_i)
  @ans = []
  @ans << @quiz.correct_answer
  @ans << @quiz.wrong_ans1
  @ans << @quiz.wrong_ans2
  @ans << @quiz.wrong_ans3

  @ans.shuffle!
  haml :parm
end

post '/ans' do
  @quiz = Quiz.find(id: request[:qid])
  if @quiz.correct_answer == request[:ans] then
    haml :ans, {}, answ: :corr, no: request[:qid]
  else
    haml :ans, {}, answ: :wrong, no: request[:qid]
  end
end


put '/quizpost' do
  @quiz = Quiz.insert({
             auther_id: @twitter.verify_credentials.id_str,
             sentence: request[:sentence],
             description: request[:description],
             correct_answer: request[:correct],
             wrong_ans1: request[:wrong],
             wrong_ans2: request[:wrong2],
             wrong_ans3: request[:wrong3],
             posted_date: Time::now
           })

  @twitter.update("#{request[:sentence]} / QuizTwitMaker http://quiztm.heroku.com/quiz/#{@quiz}") if request[:istweet]
  redirect '/'
end

get '/request_token' do
  callback_url = "#{base_url}/access_token"
  request_token = oauth_consumer.get_request_token(:oauth_callback => callback_url)
  session[:request_token] = request_token.token
  session[:request_token_secret] = request_token.secret
  redirect request_token.authorize_url
end

get '/access_token' do
  request_token = OAuth::RequestToken.new(
    oauth_consumer, session[:request_token], session[:request_token_secret])
  begin
    @access_token = request_token.get_access_token(
                                                   {},
                                                   :oauth_token => params[:oauth_token],
                                                   :oauth_verifier => params[:oauth_verifier])
  rescue OAuth::Unauthorized => @exception
    return erb %{ oauth failed: <%=h @exception.message %> }
  end
  
  session[:access_token] = @access_token.token
  session[:access_token_secret] = @access_token.secret
  
  redirect '/'
  erb %{
    oauth success!
    <dl>
      <dt>access token</dt>
      <dd><%=h @access_token.token %></dd>
      <dt>secret</dt>
      <dd><%=h @access_token.secret %></dd>
    </dl>
    <a href="/timeline">go timeline</a>
  }
end

get '/timeline' do
  redirect '/' unless @twitter
  erb %{
    <dl>
    <% @twitter.home_timeline.each do |twit| %>
      <dt><%= twit.user.name %></dt>
      <dd><%= twit.text %></dd>
    <% end %>
    </dl>
  }
end
