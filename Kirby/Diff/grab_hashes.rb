module DiffGrab
  require 'csv'
  
  # Settings
  @company_id       = 99484057
  @file_type        = :txt # csv or txt

  # File output:
  # txt: /system/diff_output_company_id_timestamp.txt
  # csv: /system/diff_output_company_id_timestamp.csv
  @output_dir       = 'public/system'
  @file_name_prefix = 'diff_output'
  # Can be downloaded for example:
  # http://test-stand.ru/system/diff_output_123_1521021269.csv

  def self.grab(args = {})
    $redis.select args.fetch(:db, 5)
    statuses   = args.fetch(:public_state, ['published', 'unpublished', 'archived'])
    statuses   = statuses.join("', '") if statuses.is_a? Array
    company_id = args.fetch(:company_id, @company_id)
    file_type  = args.fetch(:type, @file_type)

    @output_file = File.join(
      Dir.pwd,
      @output_dir,
      "#{[@file_name_prefix, company_id.to_s, Time.now.strftime('%s')].join('_')}.#{file_type}"
    )

    yml_ids = Company.find(company_id).products.where("public_state in ('#{statuses}') and yml_id is not NULL").map(&:yml_id)
    raise 'Company has not products with yml_id' if yml_ids.empty?
    return get_txt(company_id, yml_ids) if file_type.to_s == 'txt'
    get_csv(company_id, yml_ids)
  end

  def self.get_txt(company_id, yml_ids)
    f = File.open(@output_file, 'w')
    f.puts "#{'-' * 20}\n- Company_id: #{company_id}\n#{'-' * 20}"

    yml_ids.each do |yml|
      product_id = Company.find(company_id).products.where("yml_id = '#{yml}'")[0].id
      f.puts "- yml_id: #{yml}\n- product_id: #{product_id}\n#{'-' * 10}"
      hashes = $redis.hgetall "diff:company:products:#{company_id}:#{yml}"
      hashes.each {|k, v| f.puts "- #{k}: #{v}"}
      f.puts '-' * 10
    end
    f.close

    return @output_file
  end

  def self.get_csv(company_id, yml_ids)

    CSV.open(@output_file, 'w', encoding: Encoding::WINDOWS_1251, col_sep: ';') do |csv|
      csv << (header = [
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
      ])

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
end
