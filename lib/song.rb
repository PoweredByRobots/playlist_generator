# Song class
class Song
  attr_reader :id, :artist, :title, :level, :genre

  def initialize(client, id)
    @id = id.to_i
    @client = client
    results = lookup(id)
    return if results.nil?
    @artist = results['artist']
    @title = results['title']
    @level = results['genre'].to_i
    @genre = results['grouping']
  end

  def not_found?
    (artist && title).nil?
  end

  def already_added?(playlist)
    playlist.include? id
  end

  private

  def lookup(id)
    query = 'SELECT id, artist, title, grouping, genre ' \
            "FROM songlist WHERE ID=#{id}"
    result = @client.query(query)
    result.first unless result.first.nil?
  end
end
