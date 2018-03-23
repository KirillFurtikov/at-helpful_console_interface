module Helpers
  module DiffGrab
    require 'csv'

    # Settings
    COMPANY_ID = 99484057.freeze
    FILE_TYPE = :txt.freeze # csv or txt

    # File output:
    # txt: /system/diff_output_company_id_timestamp.txt
    # csv: /system/diff_output_company_id_timestamp.csv
    OUTPUT_DIR       = 'public/system'.freeze
    FILE_NAME_PREFIX = 'diff_output'.freeze
    # Can be downloaded for example:
    # http://test-stand.ru/system/diff_output_123_1521021269.csv

    PRODUCTS_HEADER = [
      'company_id',     # 0
      'yml_id',         # 1
      'hot',            # 2
      'base',           # 3
      'category',       # 4
      'measures',       # 5
      'related',        # 6
      'rubric',         # 7
      'company_traits', # 8
      'traits',         # 9
      'wholesale',      # 10
      'zero',           # 11
      'public_state',   # 12
      'images'          # 13
    ].freeze

    CATEGORIES_HEADER = [
      'company_id',     # 0
      'yml_id',         # 1
      'category',       # 2
      'parent',         # 3
      'content'         # 4
    ].freeze

    def self.on_load_message
      puts <<-HEREDOC
#{'-' * 40}
Using:
  - #{self}.products(company_id: 123, db: 0, public_state: 'deleted', type: :csv)
Default values:
  - db: 5 # integer
  - public_state: ['published', 'unpublished', 'archived'] # all available states
  - type: #{FILE_TYPE} # :csv or :txt
  - company_id: #{COMPANY_ID}
#{'-' * 40}
#{self}.categories(company_id: 123, db: 0, type: :csv)
Default values:
  - db: 5 # integer
  - company_id: #{COMPANY_ID}
  - type: #{FILE_TYPE} # :csv or :txt
#{'-' * 40}
    HEREDOC
    end

    def self.generated_at
      Time.now
    end

    def self.set_output_file(prefix, company_id, type)
      @output_file = File.join(
        Dir.pwd,
        OUTPUT_DIR,
        "#{[prefix, FILE_NAME_PREFIX, company_id.to_s, Time.now.strftime('%s')].join('_')}.#{type}"
      )
    end

    def self.products(args = {})
      $redis.select args.fetch(:db, 5)
      statuses   = args.fetch(:public_state, ['published', 'unpublished', 'archived'])
      statuses   = statuses.join("', '") if statuses.is_a? Array
      company_id = args.fetch(:company_id, COMPANY_ID)
      file_type  = args.fetch(:type, FILE_TYPE)

      set_output_file('products', company_id, file_type)

      yml_ids = Company.find(company_id).products.where("public_state in ('#{statuses}') and yml_id is not NULL").map(&:yml_id)

      raise 'Company has not products with yml_id' if yml_ids.empty?

      return get_txt(company_id, yml_ids, 'products') if file_type.to_s == 'txt'
      get_csv(company_id, yml_ids, 'products')
    end

    def self.categories(args = {})
      $redis.select args.fetch(:db, 5)
      company_id = args.fetch(:company_id, COMPANY_ID)
      file_type  = args.fetch(:type, FILE_TYPE)

      set_output_file('categories', company_id, file_type)

      yml_ids = Company.find(company_id).product_groups.map(&:yml_id)

      raise 'Company has not product groups' if yml_ids.empty?

      return get_txt(company_id, yml_ids, 'categories') if file_type.to_s == 'txt'
      get_csv(company_id, yml_ids, 'categories')
    end

    def self.get_txt(company_id, yml_ids, key)
      f = File.open(@output_file, 'w')
      header =
        if key == 'products'
          PRODUCTS_HEADER
        elsif key == 'categories'
          CATEGORIES_HEADER
        end
      key_max_length = header.max_by(&:size).size + 5
      f.puts '-' * 40
      f.puts "- #{'company_id:'.ljust(key_max_length)} #{company_id}"
      f.puts '-' * 40

      if key == 'products'
        yml_ids.each do |yml|
          product_id = Company.find(company_id).products.where("yml_id = '#{yml}'")[0].id

          f.puts "- #{'yml_id:'.ljust(key_max_length)} #{yml}"
          f.puts "- #{'product_id:'.ljust(key_max_length)} #{product_id}"

          f.puts '-' * 40
          hashes = $redis.hgetall "diff:company:products:#{company_id}:#{yml}"
          hashes.each {|k, v| f.puts "- #{(k.to_s + ':').ljust(key_max_length)} #{v}"}
          f.puts '-' * 40
        end
      elsif key == 'categories'
        yml_ids.each do |yml|
          id = Company.find(company_id).product_groups.where("yml_id = '#{yml}'")[0].id

          f.puts "- #{'yml_id:'.ljust(key_max_length)} #{yml}"
          f.puts "- #{'id:'.ljust(key_max_length)} #{id}"

          f.puts '-' * 40
          hashes = $redis.hgetall "diff:company:categories:#{company_id}:#{yml}"
          hashes.each {|k, v| f.puts "- #{(k.to_s + ':').ljust(key_max_length)} #{v}"}
          f.puts '-' * 40
        end
      end

      f.puts "Created at: #{self.generated_at}"
      f.close

      return @output_file.split('public').last
    end

    def self.get_csv(company_id, yml_ids, key)
      header =
        if key == 'products'
          PRODUCTS_HEADER
        elsif key == 'categories'
          CATEGORIES_HEADER
        end

      CSV.open(@output_file, 'w', encoding: Encoding::WINDOWS_1251, col_sep: ';') do |csv|
        csv << header

        yml_ids.each do |yml|
          hashes = $redis.hgetall "diff:company:#{key}:#{company_id}:#{yml}"
          keys   = hashes.keys
          values = Array.new(header.size)

          # fill company_id and yml_id
          values[header.index('company_id')] = company_id
          values[header.index('yml_id')]     = yml

          # fill hashes
          keys.each {|k| values[header.index(k)] = hashes[k]}
          csv << values
        end
      end
        return @output_file.split('public').last
    end

  self.on_load_message
  end
end
