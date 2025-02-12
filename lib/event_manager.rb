require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'  # Add this line at the top with other requires

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4] # Handle nil, pad with leading zeros, and truncate to 5 characters
end

def clean_phone_number(phone)
  digits = phone.to_s.gsub(/\D/, '')
  if digits.length == 10
    digits
  elsif digits.length == 11 && digits.start_with?('1')
    digits[1..-1]
  else
    "Bad number"
  end
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorLowerBody', 'legislatorUpperBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letters(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv', 
  headers: true, 
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new(template_letter)

hour_counts = Hash.new(0)  # New: initialize hour counts
day_counts  = Hash.new(0)  # New: initialize day counts

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone = clean_phone_number(row[:homephone])
  
  # New: update hour and day counts using registration date
  reg_date = row[:regdate]
  time = Time.strptime(reg_date, "%m/%d/%y %H:%M")
  hour_counts[time.hour] += 1
  day_counts[time.wday] += 1

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letters(id, form_letter)
end

# New: Print out peak registration hours
puts "Peak registration hours:"
hour_counts.sort_by { |hour, count| -count }.each do |hour, count|
  puts "#{hour}:00 - #{count} registrations"
end

# New: Print out registration days sorted by frequency
puts "Registration by day:"
day_counts.sort_by { |wday, count| -count }.each do |wday, count|
  puts "#{Date::DAYNAMES[wday]} - #{count} registrations"
end