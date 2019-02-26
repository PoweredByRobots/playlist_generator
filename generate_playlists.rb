#!/usr/bin/env ruby

require 'mysql2'
require 'pry'
require_relative 'lib/song_snake'

def db
  { host: ENV['SONGS_DB_HOSTNAME'],
    username: ENV['SONGS_DB_USER'],
    password: ENV['SONGS_DB_PWD'],
    database: ENV['SONGS_DB_NAME'] }
end

def ids(client)
  roots = []
  results = client.query(all_roots)
  results.each { |r| roots << r['root'].to_s }
  roots
end

def all_roots
  'SELECT root FROM tblbranches'
end

def some_roots # not currently needed but could be useful
  restrictions = '(select id from songlist where grouping like \"%fraser17%\")'
  all_roots + 'where root IN ' + restrictions
end

def client
  @client ||= Mysql2::Client.new(db)
end

def prompt_for_minimum_length
  print 'Minimum playlist length: '
  gets.chomp.to_i
end

def prompt_for_restrictions
  { genre: prompt_for_genre,
    levels: prompt_for_levels }
end

def prompt_for_levels
  print 'Include levels [1000, 2000, 3000, 4000, 5000]: '
  user_provided_levels || [1000, 2000, 3000, 4000, 5000]
end

def user_provided_levels
  input = gets.chomp.split(', ').map(&:to_i)
  return nil if input.empty?
  input
end

def prompt_for_genre
  print 'Limit to genres (regex) [/.*/]: '
  user_provided_genres || /.*/
end

def user_provided_genres
  input = Regexp.new gets.chomp
  return nil if input == //
end

system 'clear'

threshhold = prompt_for_minimum_length
restrictions = prompt_for_restrictions

loop do
  roots = ids(client)
  roots.reverse_each do |start_song_id|
    sleep 5
    snake = SongSnake.new(client, start_song_id)
    snake.slither(threshhold, restrictions)
  end
end
