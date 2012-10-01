# encoding: UTF-8

require 'nokogiri'
require 'ri_cal'
require 'tzinfo'
require 'active_support/time_with_zone'
require 'mechanize'
require 'highline/import'

# We expect the parsed times beeing in CEST
TIME_ZONE_OF_MANNHEIM = ActiveSupport::TimeZone.find_tzinfo('Berlin')
# We expect the sudents portal to have the following URLs
LOGIN_URL = 'https://cas.uni-mannheim.de/cas/login?service=https%3A%2F%2Fportal.uni-mannheim.de/qisserver/rds%3Fstate%3Duser%26type%3D1'
TIMETABLE_URL = 'https://portal.uni-mannheim.de/qisserver/rds?state=wplan&week=-1&act=show&pool=&show=plan&P.vx=lang&P.Print='


class CourseParserException < Exception
end

class CourseParser
  
  def initialize(html_table_element)
    @html_table_element = html_table_element
    @notiz_str = notiz_str_from html_table_element
    check_html_table_element 
  end
  
  def check_html_table_element
    # Check credibility of html_table_element
    # is it a course <table> element?
    
    # a regular course has 8 or 9 elements
    if (no_of_elements = @html_table_element.elements.size) > 10
      raise CourseParserException, "<table> contains too much sub elements: #{no_of_elements}"
    end
  end
  
  def self.potential_courses_from(source)
    case source
    when Nokogiri::HTML::Document
      doc = source
    when IO
      doc = Nokogiri(source)
    else 
      raise CourseParserException, "Unknown source type: #{source.class.name}"
    end
    
    potential_courses = []
    doc.css('table').each {|e| potential_courses << e unless e.nil? }
    raise CourseParserException, "No courses found!" if potential_courses.length == 0
    potential_courses
  end
    
  def notiz_str_from(html_table_element)
    html_table_element.content
  end
  
  def title
    # The tite of a tag is contained in an anchor tag 
    # surrounded by a table data tag having css class 'klein'
    title = @html_table_element.css('td.klein a')
    return title[0].content.strip if title.length == 1
    
    # or in awkward cases surrounded by a table data tag having css class 'plan5'
    title = @html_table_element.css('td.plan5 a')
    return title[0].content.strip if title.length == 1
     
    raise CourseParserException, 'Unable to parse title'
  end

  def start_date
    return date_from_notiz_str_with /Start\s:\S*(\d{2})\.(\d{2})\.(\d{4})/
    raise CourseParserException, 'Unable to parse start date'
  end

  def end_date
    return date_from_notiz_str_with /Ende\s:\S*(\d{2})\.(\d{2})\.(\d{4})/
    raise CourseParserException, 'Unable to parse end date'
  end

  def location
    @notiz_str.match(/Raum:\s*(.*)/) do |m|
      return m[1]
    end
    raise CourseParserException, 'Unable to parse location'
  end

  def type
    @notiz_str.match(/(Vorlesung|Übung)/) do |m|
      return m[0]
    end
    raise CourseParserException, 'Unable to parse type'
  end

  def start_time
    return hh_mm_array_from_notiz_str_with(/(\d{2}):(\d{2}) - \d{2}:\d{2},/)
    raise CourseParserException, 'Unable to parse start time'
  end

  def end_time
    return hh_mm_array_from_notiz_str_with(/\d{2}:\d{2} - (\d{2}):(\d{2}),/)
    raise CourseParserException, 'Unable to parse end time'
  end

  def interval
    @notiz_str.match(/\d{2}:\d{2} - \d{2}:\d{2}, (\w*)/) do |m|
      return m[1]
    end
    raise CourseParserException, 'Unable to parse interval'
  end

  def lecturer
    @notiz_str.match(/Lehrperson(en)?:\s*(.*)/) do |m|
      return m[2]
    end
    raise CourseParserException, 'Unable to parse lecturer'
  end

  def faculty
    @notiz_str.match(/missing_department\s*(.*)/) do |m|
      return m[1]
    end
    raise CourseParserException, 'Unable to parse faculty'
  end
  
  private
  
  def hh_mm_array_from_notiz_str_with(regex)
    @notiz_str.match(regex) do |m|
      hh = m[1].to_i
      mm = m[2].to_i
      return [hh,mm]
    end
  end
  
  def date_from_notiz_str_with(regex)
    @notiz_str.match(regex) do |m|
      yyyy = m[3].to_i
      mm = m[2].to_i
      dd = m[1].to_i
      return Date.new(yyyy,mm,dd)
    end
  end
  
end

class Course
  
  attr_accessor :title, :start_date ,:start_time ,:end_date ,:end_time,
  :location ,:type ,:interval ,:lecturer ,:faculty
                
  def self.parse_courses_from(source)
    courses = []
    potential_courses = CourseParser.potential_courses_from source
    potential_courses.each do |potential_course|
      begin
        courses << Course.parse_from(potential_course)
      rescue CourseParserException => e
        puts "Warning: Skipped unparseable table element: #{e.message}"
      end
    end
    courses
  end
  
  def self.parse_from(html_table_element)
    course = Course.new
    parse = CourseParser.new(html_table_element)
   
    course.title = parse.title
    course.start_date = parse.start_date
    course.start_time = parse.start_time
    course.end_date = parse.end_date
    course.end_time = parse.end_time
    course.location = parse.location
    course.type = parse.type
    course.interval = parse.interval
    course.lecturer = parse.lecturer
    course.faculty = parse.faculty

    course
  end

  def time_from(date,time_arr)
    t = Time.local(date.year,date.mon,date.day,time_arr[0],time_arr[1])
    t.set_tzid(TIME_ZONE_OF_MANNHEIM.name)
  end
  
  def first_event_start_time
    @first_event_start_time ||= time_from(@start_date, @start_time)
  end
  
  def first_event_end_time
    @first_event_end_time ||= time_from(@start_date, @end_time)
  end
  
  def last_event_end_time
    @last_event_end_time ||= time_from(@end_date, @end_time)
  end
  
  def to_s
    "#{@type}: #{@title}[\n" +
    "  start time: #{first_event_start_time.hour}:#{first_event_start_time.min}, end time: #{first_event_end_time.hour}:#{first_event_end_time.min}\n" +
    "  start date: #{first_event_start_time.to_date}, end date: #{last_event_end_time.to_date}\n" +
    "  location: #{@location}\n" + 
    "  interval: #{@interval}\n" +
    "  lecturer: #{@lecturer}\n" +
    "  faculty: #{@faculty}\n" 
  end

end

class Timetable
  
  def initialize(courses)
    @courses = courses
  end
  
  def to_calendar
    calendar = RiCal.Calendar do |cal|
      @courses.each do |course|
        cal.event do |event|
          event.summary("#{course.type}: #{course.title}")
          event.dtstart(course.first_event_start_time)
          event.dtend(course.first_event_end_time)
          event.location(course.location)
          event.description("Lecturer: #{course.lecturer}\nFaculty: #{course.faculty}")
          rrule = build_recurrence_rule(course)
          event.rrule_property(rrule) unless rrule.nil?
          event.alarm do |alarm|
            alarm.trigger = "-PT15M"
            alarm.action = 'AUDIO'
            alarm.description = "#{course.type}: #{course.title}"
          end
        end
      end
    end
    calendar
  end
  
  private
  
  def build_recurrence_rule(course)
    case course.interval 
    when 'wtl'
      rule = RiCal::PropertyValue::RecurrenceRule.new(nil, {})
      rule.freq = 'WEEKLY'
      rule.until = course.last_event_end_time
      return rule
    when 'Einzel'
      return nil # No rule required for single events
    else
      raise "unknown interval: #{course.interval}"
    end
  end
  
end

class HTTPClient
  
  @@login_url = LOGIN_URL
  @@timetable_url = TIMETABLE_URL
  
  def get_timetable(username, password)
    agent = Mechanize.new { |a| a.user_agent_alias = 'Mac Safari' }
    login_page = agent.get(@@login_url)
    form = login_page.form_with(:id => "fm1")
    form['username'] = username
    form['password'] = password
    form.submit
    timetable_page = agent.get(@@timetable_url)
    check_login_succeded(timetable_page.body)
    timetable_page.parser #returns the nokogiri doc
  end
  
  private
  
  def check_login_succeded(timetable_body)
    timetable_body.match(/Kein Stundenplan/) do
      raise CourseParserException, "Login to students portal failed (check your credentials)"
    end
  end
  
end


# Helper Methods
def abort_with_message(msg)
  puts msg
  puts "Error: No calendar created"
  Process.exit
end

def check_calendar_path(path)
  abort_with_message "ICS file expected. E.g. timetable.ics" unless /^.*\.ics$/ =~ path
  path
end

def http_mode
  # 1st argument is expected 
  # to be the file path of the new ics file
  @calendar_path = check_calendar_path ARGV[0]
  @calendar_file = open(@calendar_path,'w')
  
  username = ask("Enter your Username:  " )
  password = ask("Enter your Password:  " ) { |q| q.echo = '' }
  begin
    @timetable_source_name = 'Students Portal via HTTP'
    @timetable_source = HTTPClient.new.get_timetable(username, password)
  rescue CourseParserException => e 
    abort_with_message(e.message)
  end
end

def file_mode
  @timetable_source_name = ARGV[0]
  @timetable_source = open(ARGV[0])
  
  @calendar_path = check_calendar_path ARGV[1]
  @calendar_file = open(@calendar_path,'w')
end


############### Do it ###############
# Decide based on the number of arguments
# whether to read html from file or from www via http
case ARGV.length
when 1
  puts "Start iCalendar creation in http mode"
  http_mode
when 2
  puts "Start iCalendar creation in file mode"
  file_mode
else
  abort_with_message("Unknown number of arguments")
end

puts "Phase 1: Read courses from #{@timetable_source_name}"
begin
  courses = Course.parse_courses_from @timetable_source
rescue CourseParserException => e 
  abort_with_message(e.message)
end
courses.each {|course| puts "#{course.title}(#{course.type})"}
puts "Found #{courses.length} courses"

puts "\nPhase 2: Converting courses to iCal"
timetable = Timetable.new(courses)
calendar = timetable.to_calendar

puts "\nPhase 3: Saving iCal to #{@calendar_path}"
calendar.export(@calendar_file)

puts "\nFinished"



