require 'bundler'
require 'json'

Bundler.require

DB = Sequel.connect(ENV['BIBLE_API_DB'])

set :protection, except: [:json_csrf]

def get_verse_id(ref)
  record = DB[
    'select id from verses where book_id = ? and chapter = ? and verse = ?',
    ref[:book],
    ref[:chapter],
    ref[:verse]
  ].first
  record ? record[:id] : nil
end

def get_verses(ranges)
  all = []
  ranges.each do |(ref_from, ref_to)|
    start_id = get_verse_id(ref_from)
    stop_id  = get_verse_id(ref_to)
    if start_id and stop_id
      all += DB['select * from verses where id between ? and ?', start_id, stop_id].to_a
    else
      return nil
    end
  end
  all
end

get '/' do
  content_type 'application/json; charset=utf-8'
  response = {
    url: 'http://bible-api.com',
    description: 'RESTful JSON API for querying bible passages from the World English Bible.',
    creator: {
      name: 'Tim Morgan',
      url: 'http://timmorgan.org',
      twitter_url: 'https://twitter.com/seven1m'
    },
    source_code: {
      url: 'https://github.com/seven1m/bible_api',
      bugs: 'https://github.com/seven1m/bible_api/issues'
    },
    examples: {
      'single verse' => 'http://bible-api.com/john+3:16',
      'verse range' => 'http://bible-api.com/romans+12:1-2',
      'the kitchen sink' => 'http://bible-api.com/romans+12:1-2,5-7,9,13:1-9&10',
      'jsonp' => 'http://bible-api.com/john+3:16?callback=func',
      'unknown' => 'http://bible-api.com/mormon'
    },
    notes: [
      "JSONView for Chrome and JsonShow for Firefox are good JSON-viewing plugins in your browser.",
      "You don't have to use plus (+) signs for spaces. We did here so JsonShow will auto-link them.",
      "All passages returned are of the World English Bible (WEB) translation, which is in the public domain. Copy and publish freely!"
    ]
  }
  JSONP response
end

get '/:ref' do
  content_type 'application/json; charset=utf-8'
  ref_string = params[:ref].gsub(/\+/, ' ')
  ref = BibleRef::Reference.new(ref_string)
  if ranges = ref.ranges
    if verses = get_verses(ranges)
      verses.map! do |v|
        {
          book_id:   v[:book_id],
          book_name: v[:book],
          chapter:   v[:chapter],
          verse:     v[:verse],
          text:      v[:text]
        }
      end
      response = {
        reference: ref.normalize,
        verses: verses,
        text: verses.map { |v| v[:text] }.join,
        translation_id: 'WEB',
        translation_name: 'World English Bible',
        translation_note: 'The World English Bible, a Modern English update of the American Standard Version of the Holy Bible, is in the public domain. Copy and publish it freely.'
      }
      JSONP response
    else
      status 404
      response = { error: 'not found' }
      JSONP response
    end
  else
    status 404
    response = { error: 'not found' }
    JSONP response
  end
end
