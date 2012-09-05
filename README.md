StudentsCalendar
================

Students Calendar is dedicated to all students of Mannheim University, who want to use their
personal lecture timetable on their favorite mobile device or calendar app (Apple iCal, Mozilla Thunderbird, Microsift Outlook...).

It is a small ruby program to convert the personal timetable you maintained in the students portal 
to an iCalendar (.ics) file. This file can be imported as an additional calendar on most mobile devices or calendar apps.

Please note: StudentsCalendar is rather new and I encourage you to double check imported dates and times. Don't blame me if   you miss your lectures :-)

##Prerequisites
As StudentsCalendar is written in ruby you need a working ruby environment (check whether 'ruby --version' succeeds).
Additionally the following gems should be installed:
* ri_cal
* tzinfo
* activesupport
* nokogiri


##How to use
1. Logon to the students portal of Mannheim University
1. Open 'My timetable'
1. Select view options: Teaching Period
1. Select plan: long
1. Unfortunately (see limitations): Ensure you display the website in German
1. Click 'Print (HTML)'
1. Save the displayed website as 'timetable.html'
1. Download 'students_calendar.rb'
1. Open you favorite terminal and execute
   `ruby students_calendar.rb <path_to_timetable_html> <path_to_new_ics_file>`
   e.g. `ruby students_calendar.rb /Users/example/Desktop/timetable.html /Users/example/Desktop/timetable.ics`


##Limitations
* The conversion works for timetable.html downloaded in German language only
* The conversion works for view options "plan: long" and "Teaching Period" only

##Future Features
What I currently uploaded is a first version which which fulfills my aspiration to laziness, which means not to add each course to my calendar manually over and over again every semester.
I have several ideas for addiational features that might be useful.
Unfortunately time is limited and thefore I hope that others join the development.
Additional features might be:
* Enable conversion from timetable.html downloaded in English language
* Convert the script into a web application (e.g. Rails), where users just have to input the URL
* Add additional events to the calendar e.g. exams, semester dates....

##Bugs
Please use the 'Issues' functionality on github to report any kind of bugs


## LICENSE:

The MIT License (MIT)
Copyright (c) 2012 Norman Weisenburger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.