require 'net/http'
require 'json'
# require 'uri'

module SpotifyHelper

  def self.get_token
    encode = (Base64.encode64("98dde3b460bc42a6b3ea332b548b3ea2" + ':' + "3d6c772b442f4454994fa3635122fc14")).gsub("\n",'')
    uri = URI.parse("https://accounts.spotify.com/api/token")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Basic #{encode}"
    request.set_form_data(
      "grant_type" => "client_credentials",
    )

    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end

    hash = JSON.parse(response.body)
    ENV["ACCESS_TOKEN"] = hash["access_token"]
    return hash["access_token"]

  end

  def self.api_call(artist)
    formatted_artist = artist.gsub(/ /, "+")
    uri = URI.parse("https://api.spotify.com/v1/search?q=#{formatted_artist}&type=artist")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{ENV["ACCESS_TOKEN"]}"

    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
    return response
  end

  def self.genre_check(artists_array, user_genre)
    access_token = SpotifyHelper.get_token

    artists = []
    artists_array.each do |artist|

      found_artist = Artist.find_by(name: artist) # return nil or first item
      if found_artist
        artists << found_artist if found_artist.genres.pluck(:genre).any? { |word| word.include?(user_genre) }
      else # need to make a Spotify API call to get the Spotify ID
        next if !!artist.match(/[^\w\s]/) # skip if artist has funky characters

        spotify_artist_info = JSON.parse(api_call(artist).body)["artists"]["items"]

        next if spotify_artist_info.empty? # skip bands with no information

        id_from_spotify = spotify_artist_info[0]["id"]
        genre_array = spotify_artist_info[0]["genres"]

        if !spotify_artist_info[0]["images"].empty? # skip if bands do not have image (from Spotify)
          band_photo = spotify_artist_info[0]["images"][0]["url"]
        end

        new_artist = Artist.create(name: artist, spotify: id_from_spotify, image: band_photo)
          genre_array.each do |specific_genre|
            genre = Genre.find_or_create_by(genre: specific_genre)
            new_artist.genres << genre
          end
        artists << new_artist if new_artist.genres.pluck(:genre).any? { |word| word.include?(user_genre) }
      end
    end
    return artists
  end


end


