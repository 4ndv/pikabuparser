require 'nokogiri'
require 'peach'
require 'open-uri'
require 'json'

class Parser
  def to_boolean str
    str.downcase == 'true' || str == '1'
  end

  def single id
    html = open("http://pikabu.ru/story/_#{id}").read

    doc = Nokogiri::HTML(html) do |config|
      config.options = Nokogiri::XML::ParseOptions::NOERROR | Nokogiri::XML::ParseOptions::NONET
    end

    doc.encoding = 'utf-8'

    return false if html.force_encoding("utf-8").include? '404.'

    post = {}

    # ID
    post[:id] = doc.at_css('.story')['data-story-id'].to_s.to_i
    # Заголовок
    post[:title] = doc.at_css('.story__title-link').content
    # Имя автора
    post[:author] = doc.at_css('.story__author').content
    # Сообщество
    post[:community] = nil
    post[:community] = doc.at_css('.b-community-info').at_css('a')['href'].to_s.sub('/community/', '') if doc.at_css('.b-community-info')
    # Дата добавления
    post[:date] = doc.at_css('.story__date')['title'].to_s.to_i
    # Тип поста
    post[:type] = doc.at_css('.story__toggle-button')['data-story-type']
    # Рейтинг поста
    post[:rating] = doc.at_css('.story__rating-count').content.to_s.strip.to_i
    # Удален?
    post[:deleted] = false
    post[:deleted] = true if doc.at_css('.i-sprite--feed__rating-trash')
    post[:rating] = nil if post[:deleted]
    # Длиннопост
    post[:long] = to_boolean(doc.at_css('.story')['data-story-long'].to_s)
    # Моё?
    post[:own] = false
    post[:own] = true if doc.at_css('.story__authors')
    # Клубничка?
    post[:strawberry] = false
    post[:strawberry] = true if doc.at_css('.story__straw')
    # Комментариев
    post[:comments] = doc.at_css('.story__comments-count').content.to_s.to_i
    # Теги
    post[:tags] = doc.css('.story__tag').map { |i| i.content.to_s.strip }
    # Счетчики
    post[:counter_facebook] = doc.at_css('.b-social-button_type_facebook > .b-social-button__counter').content.to_s.to_i
    post[:counter_vk] = doc.at_css('.b-social-button_type_vk > .b-social-button__counter').content.to_s.to_i
    post[:counter_save] = doc.at_css('.b-social-button_type_save')['data-count'].to_s.to_i

    puts "Parsed #{post[:id]}: #{post[:title]}"

    post
  end

  def range from, to
    posts = []
    (from..to).to_a.peach(16) do |i|
      begin
        item = single(i)
        posts.push(item) if item
      rescue
        raise "Error in #{i}"
      end
    end

    posts
  end
end
