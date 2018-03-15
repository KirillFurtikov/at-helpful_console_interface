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

  HEADER = [
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
  	
  def self.on_load_message
	puts "Using:"
	puts "#{self}.grab(company_id: 123, db: 0, public_state: 'deleted', type: :csv)"
	puts "Default values:"
	puts "- db: 5 # integer"
	puts "- public_state: ['published', 'unpublished', 'archived'] # all available states"
	puts "- type: #{FILE_TYPE} # :csv or :txt"
	puts "- company_id: #{COMPANY_ID}" 
  end

  def self.grab(args = {})
    $redis.select args.fetch(:db, 5)
    statuses   = args.fetch(:public_state, ['published', 'unpublished', 'archived'])
    statuses   = statuses.join("', '") if statuses.is_a? Array
    company_id = args.fetch(:company_id, COMPANY_ID)
    file_type  = args.fetch(:type, FILE_TYPE)

    @output_file = File.join(
      Dir.pwd,
      OUTPUT_DIR,
      "#{[FILE_NAME_PREFIX, company_id.to_s, Time.now.strftime('%s')].join('_')}.#{file_type}"
    )

    yml_ids = Company.find(company_id).products.where("public_state in ('#{statuses}') and yml_id is not NULL").map(&:yml_id)
    raise 'Company has not products with yml_id' if yml_ids.empty?
    return get_txt(company_id, yml_ids) if file_type.to_s == 'txt'
    get_csv(company_id, yml_ids)
  end

  def self.get_txt(company_id, yml_ids)
    f = File.open(@output_file, 'w')
    key_max_length = HEADER.max_by(&:size).size + 5
    f.puts '-' * 40
    f.puts "- #{'company_id:'.ljust(key_max_length)} #{company_id}"
    f.puts '-' * 40

    yml_ids.each do |yml|
      product_id = Company.find(company_id).products.where("yml_id = '#{yml}'")[0].id

      f.puts "- #{'yml_id:'.ljust(key_max_length)} #{yml}"
      f.puts "- #{'product_id:'.ljust(key_max_length)} #{product_id}"

      f.puts '-' * 40
      hashes = $redis.hgetall "diff:company:products:#{company_id}:#{yml}"
      hashes.each {|k, v| f.puts "- #{(k.to_s + ':').ljust(key_max_length)} #{v}"}
      f.puts '-' * 40
    end
    f.close

    return @output_file
  end

  def self.get_csv(company_id, yml_ids)

    CSV.open(@output_file, 'w', encoding: Encoding::WINDOWS_1251, col_sep: ';') do |csv|
      csv << HEADER

      yml_ids.each do |yml|
        hashes = $redis.hgetall "diff:company:products:#{company_id}:#{yml}"
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
