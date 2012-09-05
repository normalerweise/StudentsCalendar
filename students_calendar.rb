# encoding: UTF-8

require 'nokogiri'
require 'open-uri'
require 'ri_cal'
require 'tzinfo'
require 'active_support/time_with_zone'

# We expect the parsed times beeing in CEST
TIME_ZONE_OF_MANNHEIM = ActiveSupport::TimeZone.find_tzinfo('Berlin')

class CourseParserException < Exception
end

class CourseParser
  
  def initialize(html_table_element)
    @html_table_element = html_table_element
    @notiz_str = notiz_str_from html_table_element 
  end
  
  def self.potential_courses_from(source)
    case source
    when Nokogiri::HTML::Document
      doc = source
    when IO
      doc = Nokogiri::HTML(source)
    else 
      raise CourseParserException, "Unknown source type: #{source.class.name}"
    end
    
    potential_courses = []
    doc.css('table').each {|e| potential_courses << e unless e.nil? }
    potential_courses
  end
    
  def notiz_str_from(html_table_element)
    html_table_element.content
  end
  
  def title
    # The tite of a tag is contained in an anchor tag 
    # surrounded by a table data tag having css class 'klein'
    title = @html_table_element.css('td.klein a')
    if title.length == 1
      return title[0].content.strip
    end 
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
          event.rrule_property(build_recurrence_rule(course))
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
    
    raise "unknown interval: #{course.interval} " if course.interval != 'wtl'
    
    rule = RiCal::PropertyValue::RecurrenceRule.new(nil, {})
    rule.freq = 'WEEKLY'
    rule.until = course.last_event_end_time
    rule
  end
  
end


def check(path,message)
  if path.nil?
    puts message
    Process.exit
  end
end

timetable_path = ARGV[0] 
calendar_path  = ARGV[1]
check timetable_path, "Error invalid timetable html path: #{timetable_path}"
check calendar_path,  "Error invalid calendar output path: #{calendar_path}" 

puts "Phase 1: Read courses from #{timetable_path}"
courses = Course.parse_courses_from open(timetable_path)
courses.each {|course| puts "#{course.title}(#{course.type})"}
puts "Found #{courses.length} courses"

puts "\nPhase 2: Converting courses to iCal"
timetable = Timetable.new(courses)
calendar = timetable.to_calendar

puts "\nPhase 3: Saving iCal to #{calendar_path}"
calendar.export(open(calendar_path,'w'))

puts "\nFinished"



