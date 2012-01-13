# -*- coding: utf-8 -*-
require 'sequel'

Sequel.extension :pagination

Sequel::Model.plugin :schema
Sequel::Model.plugin :validation_class_methods

Sequel.connect(ENV['DATABASE_URL'] || "sqlite://co.db")

class Quiz < Sequel::Model
  unless table_exists?
    set_schema do
      primary_key :id
      Integer :auther_id
      text :sentence
      text :description
      String :correct_answer
      String :wrong_ans1
      String :wrong_ans2
      String :wrong_ans3
      timestamp :posted_date
    end
    create_table
  end

  def validate
#    errors.add(:sentence, "問題文を入れてください") if sentence.nil? || sentence.empty?
#    errors.add(:sentence, "正解を入力してください") if correct_answer.nil? || correct_answer.empty?
#    errors.add(:sentence, "一つ以上の間違いを入力してください") if wrong_answer.nil? || wrong_answer.empty?
  end

  def date
    self.posted_date.strftime("%Y-%m-%d %H:%M:%S")
  end

  def formatted_sentence
    Rack::Utils.escape_html(self.sentence).gsub(/\n/, "<br>")
  end
end
