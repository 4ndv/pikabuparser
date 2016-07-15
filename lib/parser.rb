require 'nokogiri'
require 'parallel'
require 'open-uri'
require 'json'

class String
  def string_between_markers marker1, marker2
    self[/#{Regexp.escape(marker1)}(.*?)#{Regexp.escape(marker2)}/m, 1]
  end

  def string_between_markers_with_markers marker1, marker2
    marker1 + self[/#{Regexp.escape(marker1)}(.*?)#{Regexp.escape(marker2)}/m, 1] + marker2
  end
end

class Parser
  def to_boolean str
    str.downcase == 'true' || str == '1'
  end

  def single id
    html = open("http://pikabu.ru/story/_#{id}").read

    return false if html.encode(Encoding::UTF_8).include? '404. Упс, такой страницы у нас нет'
    return false if html.encode(Encoding::UTF_8).include? '<i class="story__pin-o"></i>'
    return false if html.encode(Encoding::UTF_8).include? '<i class="story__pin"></i>'

    html2 = html.string_between_markers_with_markers('<!--story_', '<!--- social segment') + '-->'

    doc = Nokogiri::HTML(html2) do |config|
      config.options = Nokogiri::XML::ParseOptions::NOERROR | Nokogiri::XML::ParseOptions::NONET
    end

    doc.encoding = 'utf-8'

    post = {}

    # ID
    post[:id] = doc.at_css('.story')['data-story-id'].to_s.to_i
    # Заголовок
    post[:title] = doc.at_css('.story__title-link').content
    # Имя автора
    post[:author] = doc.at_css('.story__author').content
    # Сообщество
    # post[:community] = doc.at_css('.b-community-info').at_css('a')['href'].to_s.sub('/community/', '') if doc.at_css('.b-community-info')
    post[:community] = doc.at_css('.story__header-additional-wrapper').xpath('//a[starts-with(@href, "/community/")]/@href').to_s.sub('/community/', '')
    post[:community] = nil if post[:community] == ''
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

    post
  end

  def range from, to
    posts = []
    Parallel.each((from..to), in_threads: 16, progress: ' Fetching...') do |i|
      begin
        item = single(i)
        if item
          puts "[THREAD #{Parallel.worker_number}] Fetched #{item[:id]}: #{item[:title]}"
          posts.push(item)
        end
      rescue
        raise "Error in #{i}"
      end
    end

    posts
  end
end
