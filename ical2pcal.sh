#!/bin/bash 

# Copyright (c) 2010 Jörg Kühne <jk-ical2pcal at gmx dot de> 
# Copyright (c) 2008 Francisco José Marín Pérez <pacogeek at gmail dot com>

# All rights reserved. (The Mit License)

#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in
#all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#THE SOFTWARE.

# Changes from Jörg Kühne
# v0.0.2:
# - auto conversion from UTC times to local times
# - support of multiple day events
# - support of begin/end times

# ----------------------------------------------------------------------
# Configuration

# if the gnu date command is not in default path, please specify the command
# with full path
GNU_DATE_COMMAND=""

# ----------------------------------------------------------------------
# Code starts here

if [ -z "$GNU_DATE_COMMAND" ]; then
   GNU_DATE_COMMAND=date
fi

# check date command for gnu version
TEST_DATE=`"$GNU_DATE_COMMAND" -d 20100101 +%Y%m%d`
if [ "x$TEST_DATE" != "x20100101" ]; then
   echo "Gnu version of date command not found. Please set correct config value."
   echo " "
   exit 1
fi

help() { # Show the help 
   cat << EOF
ical2pcal v0.0.2 - Convert iCalendar (.ics) data files to pcal data files  

Usage:   ical2pcal  [-E] [-o <file>] [-h] file 
         
         -E Use European date format (dd/mm/yyyy)

         -o <file> Write the output to file instead of to stdout 
         
         -h Display this help

The iCalendar format (.ics file extension) is a standard (RFC 2445)
for calendar data exchange. Programs that support the iCalendar format
are: Google Calendar, Apple iCal, Evolution, Orange, etc.

The iCalendar format have many objects like events, to-do lists,
alarms, journal entries etc. ical2pcal only use the events
in the file showing in the pcal file the summary and the time of
the event, the rest information of the event like
description or location are commented in the pcal file (because
usually this information does not fit in the day box).

Currently automatic detection and conversion to local time of time values 
in UTC is implemented. All other time values are assumed as local times.

EOF
}

european_format=0
output="/dev/stdout"

while getopts Eho: arg
do
   case "$arg"
   in
      E) european_format=1;;

      o) output="$OPTARG";;

      h) help 
         exit 0;;

      ?) help
         exit 1;;
   esac
done

shift $(( $OPTIND - 1))

if [ $# -lt 1 ]
then
   help
   exit 0
fi

cat $* |
awk '
BEGIN{
   RS = ""
}

{
   gsub(/\r/,"",$0) # Remove the Windows style line ending 
   gsub(/\f/,"",$0) # Remove the Windows style line ending 
   gsub(/\n /,"", $0) # Unfold the lines
   gsub(/\\\\/,"\\",$0)
   gsub(/\\,/,",",$0)
   gsub(/\\;/,";",$0)
   gsub(/\\n/," ",$0)
   gsub(/\\N/," ",$0)
   print
}' |
awk -v european_format=$european_format -v date_command="$GNU_DATE_COMMAND" '
BEGIN {
   FS = ":" #field separator
   print "# Creator: ical2pcal"
   print "# include this file into your .calendar file with: include \"a_file.pcal\"\n" 
}

$0 ~ /^BEGIN:VEVENT/ {
   all_day_event = 0
   utc_time = 0
   summary = ""
   localtion = ""
   description = ""

   while ($0 !~ /^END:VEVENT/)
   {
      if ($1 ~ /^DTSTART/)
      {
         year_start = substr($2, 1, 4)
         month_start = substr($2, 5, 2)
         day_start = substr($2, 7, 2)

         if ($1 ~ /VALUE=DATE/) 
         {
            all_day_event = 1 
         }
         else
         {
            hour_start = substr($2, 10, 2)
            minute_start = substr($2, 12, 2)
            UTCTAG = substr($2, 16, 1)

            if (UTCTAG == "Z")
            {
               utc_time = 1
            }
         }
      }

      if ($1 ~ /^DTEND/)
      {
         year_end = substr($2, 1, 4)
         month_end = substr($2, 5, 2)
         day_end = substr($2, 7, 2)

         if ($1 ~ /VALUE=DATE/) 
         {
            all_day_event = 1 
         }
         else
         {
            hour_end = substr($2, 10, 2)
            minute_end = substr($2, 12, 2)
         }
      }

      if ($1 ~ /^SUMMARY/)
      {
         sub(/SUMMARY/,"",$0)
         sub(/^:/,"",$0)
         summary = $0
      }
      if ($1 ~ /^LOCATION/)
      {
         sub(/LOCATION/,"",$0)
         sub(/^:/,"",$0)
         location = $0
      }

      if ($1 ~ /^DESCRIPTION/)
      {
         sub(/DESCRIPTION/,"",$0)
         sub(/^:/,"",$0)
         description = $0
      }
      getline
   }
   print "#### BEGIN EVENT -----------------------------------"

   if (! all_day_event && utc_time)
   {
      # Convert Date/Time from UTC to local time
      
      tmp_date_start = year_start month_start day_start "UTC" hour_start minute_start
      command = date_command " -d" tmp_date_start " +%Y%m%d%H%M"
      command | getline captureresult
      close(command)
      year_start = substr(captureresult, 1, 4)
      month_start = substr(captureresult, 5, 2)
      day_start = substr(captureresult, 7, 2)
      hour_start = substr(captureresult, 9, 2)
      minute_start = substr(captureresult, 11, 2)

      tmp_date_end = year_end month_end day_end "UTC" hour_end minute_end
      command = date_command " -d " tmp_date_end " +%Y%m%d%H%M"
      command | getline captureresult
      close(command)
      year_end = substr(captureresult, 1, 4)
      month_end = substr(captureresult, 5, 2)
      day_end = substr(captureresult, 7, 2)
      hour_end = substr(captureresult, 9, 2)
      minute_end = substr(captureresult, 11, 2)
   }

   date_start = year_start month_start day_start
   date_end = year_end month_end day_end

   # avoid new day entry if end time is 12AM
   if (hour_end == "00" && minute_end == "00")
   {
      command = date_command "  -d \"" date_end " -1 day\"" " +%Y%m%d"
      command | getline captureresult
      close(command)
      year_end = substr(captureresult, 1, 4)
      month_end = substr(captureresult, 5, 2)
      day_end = substr(captureresult, 7, 2)

      date_end = year_end month_end day_end
   }

   if (all_day_event)
   {
      # Hack to save calculation time - not works for last day of month
      if (date_start + 1 == date_end)
      {
         if (european_format)
         {
         print day_start "/" month_start "/" year_start " " summary
         }
         else
         {
         print month_start "/" day_start "/" year_start " " summary
         }
      }
      else
      {
         if (date_start < date_end) 
         {
            date_next = date_start
            while (date_next < date_end)
            {
               tmp_year_next = substr(date_next, 1, 4)
               tmp_month_next = substr(date_next, 5, 2)
               tmp_day_next = substr(date_next, 7, 2)

               if (european_format)
               {
                print tmp_day_next "/" tmp_month_next "/" tmp_year_next " " summary
               }
               else
               {
                print tmp_month_next "/" tmp_day_next "/" tmp_year_next " " summary
               }

               command = date_command  " -d \"" date_next " 1 day\"" " +%Y%m%d"
               command | getline captureresult
               close(command)
               date_next = captureresult
            }
         }
         else
         {
            # Should not happen
            if (european_format)
            {
               print day_start "/" month_start "/" year_start " " summary
            }
            else
            {
               print month_start "/" day_start "/" year_start " " summary
            }
         }
      }
   }
   else
   {
      if (date_start < date_end) 
      {
         # first date with start time
         if (european_format)
         {
            print day_start "/" month_start "/" year_start " " hour_start ":" minute_start " -> " summary
         }
         else
         {
            command = date_command " -d " hour_start ":" minute_start " +%I:%M%p"
            command | getline time_start
            close(command)

            print month_start "/" day_start "/" year_start " " time_start " -> " summary
         }

         #middle days without time
         command = date_command  " -d \"" date_start " 1 day\"" " +%Y%m%d"
         command | getline captureresult
         close(command)
         date_next = captureresult
         while (date_next < date_end)
         {
            tmp_year_next = substr(date_next, 1, 4)
            tmp_month_next = substr(date_next, 5, 2)
            tmp_day_next = substr(date_next, 7, 2)

            if (european_format)
            {
               print tmp_day_next "/" tmp_month_next "/" tmp_year_next " " summary
            }
            else
            {
               print tmp_month_next "/" tmp_day_next "/" tmp_year_next " " summary
            }

            command = date_command " -d \"" date_next " 1 day\"" " +%Y%m%d"
            command | getline captureresult
            close(command)
            date_next = captureresult
         }

         # last day with end time
         if (european_format)
         {
            print day_end "/" month_end "/" year_end " -> " hour_end ":" minute_end " " summary
         }
         else
         {
            command = date_command " -d " hour_end ":" minute_end " +%I:%M%p"
            command | getline time_end
            close(command)

            print month_end "/" day_end "/" year_end " -> " time_end " " summary
         }
      }
      else
      {
         if (european_format)
         {
            print day_start "/" month_start "/" year_start " " hour_start ":" minute_start "-" hour_end ":" minute_end " " summary
         }
         else
         {
            command = date_command " -d " hour_start ":" minute_start " +%I:%M%p"
            command | getline time_start
            close(command)

            command = date_command " -d " hour_end ":" minute_end " +%I:%M%p"
            command | getline time_end
            close(command)

            print month_start "/" day_start "/" year_start " " time_start "-" time_end " " summary
         }
      }
   }
   if (location != "")
   {
      if (european_format)
      {
         print "#"day_start "/" month_start "/" year_start" location: "location
      }
      else
      {
         print "#"month_start "/" day_start "/" year_start" location: "location
      }
   }
   if (description != "")
   {
      if (european_format)
      {
         print "#"day_start "/" month_start "/" year_start" description: "description
      }
      else
      {
         print "#"month_start "/" day_start "/" year_start" description: "description
      }
   }
   print "#### END EVENT -------------------------------------\n"
}

END {

}' > $output 


