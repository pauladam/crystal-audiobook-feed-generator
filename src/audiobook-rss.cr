require "./audiobook-rss/*"
require "json"

# Discovers audiobooks in a given folder and produces an rss feed of the
# included items
#
#   ex.  $ ./audiobook-rss > feed.rss 

config = JSON.parse(File.read("config.json")) as Hash

module Audiobook::Rss

    class TagsData
        JSON.mapping({
            title: String,
            artist: String,
            album: String,
            album_artist: String,
            creation_time: String
        })
    end

    class FormatData
        JSON.mapping({
            duration: String,
            size: String,
            tags: TagsData
        })
    end

    class Metadata
        JSON.mapping({
            format: FormatData
        })
    end

    body = [] of String

    header = %(
        <rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" version="2.0">
          <channel>
            <title>#{config["feed_title"]}</title>
            <link>#{config["link"]}/</link>
            <description>#{config["description"]}</description>
            <itunes:author>#{config["author"]}</itunes:author>
            <copyright></copyright>
            <language>en-us</language>
            <pubDate>#{config["publication_date"]}</pubDate>
            <lastBuildDate>#{Time.now}</lastBuildDate>
            <itunes:image href="#{config["feed_image_url"]}"/>
    ).rstrip
    trailer = %(
          </channel>
        </rss>
    ).rstrip

    items = Dir.glob("#{config["audiobook_dir"]}/*").compact_map{ |item|
       if !item.includes? ".rss"
           item
       end
    }.each{ |item|
        fn = item.split("/")[-1]
        json_str = `ffprobe -i "#{item}" -sexagesimal -show_format -v quiet -of json 2>&1`.rstrip
        metadata = Metadata.from_json(json_str)
        url = "%s%s" % [config["url_base"], fn]

        item_xml = %(
            <item>
              <itunes:author>#{metadata.format.tags.artist}</itunes:author>
              <itunes:duration>#{metadata.format.duration}</itunes:duration>
              <title>#{metadata.format.tags.album_artist} - #{metadata.format.tags.title}</title>
              <guid isPermaLink="true">#{url}</guid>
              <description></description>
              <pubDate>#{metadata.format.tags.creation_time}</pubDate>
              <enclosure length="#{metadata.format.size}" url="#{url}" type="audio/mpeg"/>
            </item>
        ).rstrip
        body << item_xml

    }

    xml = header + body.join("") + trailer
    output_fn = "%s/%s" % [config["audiobook_dir"], config["output_feed"]]
    File.write(output_fn, xml)
    feed_url = "%s%s" % [config["url_base"], config["output_feed"]]
    puts feed_url

end
