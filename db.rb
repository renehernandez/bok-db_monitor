require 'mysql2'
require 'benchmark'
require 'mail'

Process.daemon(true)

options = { :address              => "smtp.gmail.com",
            :port                 => 587,
            :user_name            => 'renehr9102@gmail.com',
            :password             => '91020229803',
            :authentication       => 'plain',
            :enable_starttls_auto => true  }



Mail.defaults do
  delivery_method :smtp, options
end

pid = Process.fork do

  client = Mysql2::Client.new(host: 'localhost',
        username: "interview_user", password: 'interview_pass')

  ROWS_NUMBER = 100000

  insert_query = "INSERT INTO interview.articles (id, name) VALUES"

  (ROWS_NUMBER - 1).times do |i|
    insert_query << " (#{i}, '#{i}_name'),"
  end

  insert_query << " (#{ROWS_NUMBER - 1}, '#{ROWS_NUMBER - 1}_name');"

  client.query(insert_query)

  select_query = "SELECT * FROM interview.articles;"

  status_query = "SELECT * FROM performance_schema.global_status"

  upper_bound = 0.06

  while true do
    time_obj = Benchmark.measure {
      results = client.query(select_query)
    }

    if time_obj.real >= upper_bound
      results = client.query(status_query)
      output = ""

      results.each do |r|
        output << "#{r["VARIABLE_NAME"]} #{r["VARIABLE_VALUE"]}\n"
      end

      File.open("db.log", "w+") do |f|

        f.puts "============================="
        f.puts "Time: #{Time.now}"
        f.puts "VARIABLE_NAME VARIABLE_VALUE"
        f.puts output

      end

      Mail.deliver do
        from 'db@monitor.server'
        to 'rhern078@uottawa.ca'
        subject 'Database Perfomance Degradation'
        body output
      end

    end
  end
end
