require 'io/console'
require 'yaml'

CONFIG = YAML.load_file(File.join(__dir__, 'config.yml')).freeze
EDGING = '# '.freeze
DELIMITER = (EDGING.strip * 30).freeze
OPTIONS = {
  1 => 'Генерировать отчет',
  2 => 'Запустить сервер',
  3 => 'Выйти'
}.freeze


def main_menu
  puts "#{EDGING} Выберите действие:"
  OPTIONS.each_pair { |k, v| puts "#{EDGING} #{k}) #{v}" }
  select_menu
end

def define_project_menu
  puts "#{EDGING} Выбери проект:"
  CONFIG['Paths']['Projects'].each_with_index { |(k, _), i| puts "#{EDGING} #{i + 1}) #{k}" }
  menu_item = STDIN.getch
  CONFIG['Paths']['Projects'].keys[menu_item.to_i - 1] # Return project name from key by index
end

def show_menu
  puts DELIMITER
  yield
end

def select_menu
  menu_item = STDIN.getch.to_i
  case menu_item
  when 1 then show_menu { generate_report }
  when 2 then run_server
  when 3 then quit
  else
    puts menu_item
  end
end

def generate_report
  project = define_project_menu
  report_dir = Time.now.strftime("%Y%m%d_%H%M%S")
  test_results = "#{CONFIG['Paths']['Projects'][project]}\\allure"
  output_dir = "#{CONFIG['Paths']['Allure']}\\reports\\#{project}\\#{report_dir}"

  return unless Dir.exist?(test_results)
  puts "#{EDGING} Генерирую..."
  system(`start /WAIT /MIN "Генерация отчета Allure" cmd /C call allure generate #{test_results} -o #{output_dir}`)
  puts "#{EDGING} Готово: #{output_dir}"
  puts "#{EDGING} Запустить сервер? y,n"
  key = STDIN.getch
  run_server if 'y' == key.to_s
end

def run_server
  port = CONFIG['Server']['port'].to_i
  system(`start /WAIT /MIN "Allure server" cmd /C call allure open #{CONFIG['Paths']['Allure']}\\reports -p #{port}`)
end

def quit
  puts "Executing {_#{__method__}_}"
end

show_menu { main_menu }
