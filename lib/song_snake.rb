require 'pry'
require 'digest'
require_relative 'song'

# Song Snake
class SongSnake
  attr_reader :unique_hash, :ids, :current_song, :read_only

  def initialize(client, start_song_id, read_only = true)
    @client = client
    @read_only = read_only
    @ids = [start_song_id.to_i]
    @current_song = Song.new(client, start_song_id)
    @unique_hash = Digest::SHA256.new
    @unique_hash.update(start_song_id)
  end

  def drive_letter
    'C:'
  end

  def music_path
    '/Users/you/Music'
  end

  def mac_playlist_path
    './playlists/'
  end

  def win_playlist_path
    '/Users/you/Music/Playlists/'
  end

  def slither(threshhold, restrictions, playlist = [])
    return if @current_song.not_found?
    return unless restrictions[:levels].include? @current_song.level
    index = 2
    playlist << song_deets
    while friends.count > 0
      @current_song = pick_next_track(restrictions)
      return if @current_song.nil?
      @unique_hash.update(current_song.id.to_s)
      @ids << current_song.id
      playlist << song_deets
      index += 1
    end
    return unless playlist.count >= threshhold
    enumerate(playlist)
    return if read_only
    write_to_folder(ids, playlist, truncate(unique_hash.to_s, 8))
  end

  private

  def write_to_folder(track_ids, playlist, playlist_id)
    playlist_name = playlist_title(playlist) + " (#{playlist_id})"
    full_path = mac_playlist_path + playlist_name + '/'
    return if File.exist?(full_path)
    Dir.mkdir(full_path)
    track_ids.each_with_index do |id, track_no|
      track_no += 1
      old_name = win_to_mac(lookup_by_id('filename', id))
      new_name = full_path + "#{track_no}. " +
                 sanitize(lookup_by_id('artist', id)) +
                 ' - ' + sanitize(lookup_by_id('title', id)) + '.mp3'
      FileUtils.ln_s(old_name, new_name)
    end
    sleep 10
    return if read_only
    save_as_pls(track_ids, win_playlist_path, playlist_name)
  end

  def sanitize(filename)
    filename.strip.gsub!(/[[:space:]]+/u, ' ')
    filename.strip.gsub(/[\x00-\x1F\/\\:\*\?\"<>\|]/u, '')
  end

  def win_to_mac(filename)
    mac_filename = filename
    mac_filename.tr! '\\', '/'
    mac_filename.sub! drive_letter, music_path
  end

  def save_as_pls(ids, path, filename)
    index = 0
    contents = "[playlist]\n"
    ids.each do |id|
      index += 1
      contents += 'File' + index.to_s + '='
      contents += lookup_by_id('filename', id) + "\n"
      contents += 'Title' + index.to_s + '='
      contents += lookup_by_id('artist', id) + ' - '
      contents += lookup_by_id('title', id) + "\n"
    end
    contents += 'NumberOfEntries=' + index.to_s + "\n"
    contents += 'Version=2'
    playlist_file = path + filename + '.pls'
    puts 'Writing playlist: ' + playlist_file
    File.write(playlist_file, contents)
  end

  def truncate(string, length)
    string[0..length]
  end

  def enumerate(list)
    puts playlist_title(list)
    playlist_title(list).length.times { putc '=' }
    printf "\n"
    list.each_with_index { |l, index| puts "#{(index + 1)}. #{l}" }
    printf "\n\n"
  end

  def playlist_title(playlist)
    first_artist = playlist.first.partition(' - ').first
    last_artist = playlist.last.partition(' - ').first
    first_artist + ' to ' + last_artist
  end

  def song_deets
    "[#{current_song.level}] #{current_song.artist} - #{current_song.title}"
  end

  def pick_next_track(restrictions)
    id = restrictions ? filtered_friend(restrictions) : random_friend_id
    return nil unless id
    Song.new(@client, id)
  end

  def random_friend_id
    friends.sample
  end

  def friends
    friends = []
    results = @client.query(
      "SELECT branch FROM tblbranches WHERE root=#{current_song.id}")
    results.each { |row| friends << row['branch'] }
    friends = remove_dead(friends)
    remove_already_added(friends)
  end

  def already_added?
    ids.include? current_song.id
  end

  def remove_already_added(songs)
    songs.reject { |f| Song.new(@client, f).already_added?(ids) }
  end

  def remove_dead(friends)
    friends.reject { |f| Song.new(@client, f).not_found? }
  end

  def lookup_by_id(field, id)
    result = @client.query("SELECT #{field} FROM songlist WHERE ID=#{id}")
    result.first[field] unless result.first.nil?
  end

  def filtered_friend(restrictions)
    friends.each { |id| return id if valid?(id, restrictions) }
    nil
  end

  def valid?(id, restrictions)
    song = Song.new(@client, id)
    return false if song.genre.match(restrictions[:genre]).nil?
    return false unless restrictions[:levels].include? song.level
    true
  end
end
