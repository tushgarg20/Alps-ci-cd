#!/usr/intel/pkgs/ruby/1.9.3-p0/bin/ruby

require 'fileutils'
require 'zlib' # for Zlib::GzipReader
require 'csv'
require 'optparse'


$logbuffer = ""

$execute_commands = true
$delete_stat_file = true
$halt_on_error = true


def save_to_logbuffer(output)
  if $logbuffer.nil?
    $logbuffer = ""
  end
  $logbuffer = $logbuffer + output.to_s + "\n"
end

def print_and_save_to_logbuffer(output)
  puts output
  save_to_logbuffer(output)
end

def send_log_to_admin
  mailing_list_arr = ["jhillel"]
  print_and_save_to_logbuffer "\nSending log email to admins: #{mailing_list_arr.to_s}"
  subject = "Log for ALPS missing counters script"
  mailing_list = mailing_list_arr.join(" ")
  $logbuffer.gsub!("\"", "\\\"")
  $logbuffer.gsub!("\'", "\\\"")
  $logbuffer.gsub!("\`", "\\\"")
  email_commandline = "echo \"#{$logbuffer}\" | mail #{mailing_list} -s \"#{subject}\""
#  puts "\nThe email command line is:\n#{email_commandline}\nSending email...\n"
#  print_and_save_to_logbuffer email_commandline
#  if ($execute_commands)
    %x[#{email_commandline}]
#  end
end


def run_cmd(command, log_file_name)
  print_and_save_to_logbuffer "Time: " + Time.now.strftime("%y%m%d_%H%M%S")
  print_and_save_to_logbuffer "\nRunning command:\n" + command + "\n\n"

  command = "#{command} 2>&1"

  retCode = true
  if ($execute_commands)
    log_output = %x[#{command}]
    retCode = $?.success?
    if retCode != true
      print_and_save_to_logbuffer "Error in execution!"
    else
      print_and_save_to_logbuffer "Execution succeeded"
    end

    print_and_save_to_logbuffer "Writing log to #{log_file_name}"
    File.open(log_file_name, "w") do |f|
      f.write(log_output)
      f.flush
      f.close
    end

    print_and_save_to_logbuffer "Updating permissions of #{log_file_name}"
    %x[chgrp arch_gst #{log_file_name}]
    %x[chmod 660 #{log_file_name}]
  end 

  print_and_save_to_logbuffer "Time: " + Time.now.strftime("%y%m%d_%H%M%S")
  
  if ( (!retCode) and ($halt_on_error) )
    raise "Execution failed for command:\n" + command + "\n"
  end
end

def run_keiko(coho_path, trace, output_dir, time_stamp)
  print_and_save_to_logbuffer "\nRunning Keiko..."
  [coho_path].each do |path|
    if (!File.exists?(path))
      raise "Error: can't find this path: \"" + path + "\""
    end
  end 

  coho_basic_exec_cmd_min = "#{coho_path}/keiko -cfg #{coho_path}/config/skl.cfg -heartbeat 1000"
#  coho_basic_exec_cmd = "#{coho_basic_exec_cmd_min} -e 7000 -clear_stats 5000 -t #{trace}"
  coho_basic_exec_cmd_smt = "#{coho_basic_exec_cmd_min} -e 0:7000,1:7000 -clear_stats 0:5000,1:5000 -t #{trace} -t #{trace} -twolit 1 -nthreads 2"

  stats_dir = "#{output_dir}/stats"
  if ($execute_commands)
    FileUtils.mkdir_p(output_dir) if !File.exists?(output_dir)
    FileUtils.mkdir_p(stats_dir) if !File.exists?(stats_dir)
  end

  stat_file_path = "#{stats_dir}/pv_with_trad_and_zero_stats_smt.stats.gz"

  if (!File.exists?(stat_file_path))
    command = "#{coho_basic_exec_cmd_smt} -core_histo_enable_all 1 -print_zero_stats 1 -print_zero_stats_all_indexes 1 -print_stats_with_start_end_tag_prefix 0 -calc_exec_power_modeling_stats 1 -stats #{stat_file_path}"
    log_file_name = "#{output_dir}/keiko_run_#{time_stamp}.log"
    run_cmd(command, log_file_name)
  else
    print_and_save_to_logbuffer "Stats file already exists, so skipping Keiko execution."
  end

  raise "Error: Keiko didn't generate the stats file!" if !File.exists?(stat_file_path)

  return stat_file_path
end

def run_alps(alps_path, alps_formulas_path, stat_file_path, output_dir, time_stamp)
  print_and_save_to_logbuffer "\nRunning ALPS..."
  [alps_path, alps_formulas_path].each do |path|
    if (!File.exists?(path))
      raise "Error: can't find this path: \"" + path + "\""
    end
  end 

  exp_name = "exp"
  alps_basic_exec_cmd = "#{alps_path}/scripts/alps.pl -exp #{exp_name} -powerformulaslist #{alps_formulas_path} -TDP 5% -cfg #{alps_path}/config/skl/skl_1core_4slc.cfg " +
                        "-consider_counter_as_exists_even_if_zero_value -consider_histogram_as_exists_even_if_empty -nooutput_counters_values -nocalculate_groups -nooutput_formula_files"

  alps_out_dir = "#{output_dir}/alps_output"
  if ($execute_commands)
    FileUtils.mkdir_p(output_dir) if !File.exists?(output_dir)
    FileUtils.mkdir_p(alps_out_dir) if !File.exists?(alps_out_dir)
  end

  missing_counters_report_file = "#{alps_out_dir}/stats_not_used_output_#{exp_name}.xls.gz"

  if (!File.exists?(missing_counters_report_file))
    command = "#{alps_basic_exec_cmd} -o #{alps_out_dir} -logs \"#{stat_file_path}\""
    log_file_name = "#{output_dir}/alps_run_#{time_stamp}.log"
    run_cmd(command, log_file_name)
  else
    print_and_save_to_logbuffer "ALPS missing_counters_report_file file already exists, so skipping ALPS execution."
  end

  raise "Error: ALPS didn't generate the missing counters report file!" if !File.exists?(missing_counters_report_file)

  return missing_counters_report_file
end

def read_missing_counters_report(missing_counters_report_file)
  print_and_save_to_logbuffer "\nReading missing counters report..."
  if (!File.exists?(missing_counters_report_file))
    raise "Error: can't find the missing counters report file: " + missing_counters_report_file
  end

  missing_counters_report = Hash.new
  
  Zlib::GzipReader.open(missing_counters_report_file) {|gz|
    header = gz.readline
    if (!(/Counter\ttotal EC\tLocation info/.match(header)) )
      raise "Error: Can't find the header line in the missing counters report file!"
    end

    gz.each_line do |line|
      columns = line.split("\t")
      counter_name = columns.shift
      total_ec = columns.shift
      missing_counters_report[counter_name] = Hash.new
      missing_counters_report[counter_name][:raw_counter_data_line] = line
      missing_counters_report[counter_name][:total_ec] = total_ec
      missing_counters_report[counter_name][:location_info] = columns
    end
  }
#return the parsed hash, or also the unzipped file so we can send it as attachment to easily be opened in Excel?  
  return missing_counters_report
end

def add_owners_mapping(block, loc_substr, owners, owners_mapping)
  if (not owners_mapping.has_key?(:blocks)) # Initialize the main hash
    owners_mapping[:blocks] = Hash.new
  end

  if (not owners_mapping[:blocks].has_key?(block))  # Initialize the block hash
    owners_mapping[:blocks][block] = Hash.new
    owners_mapping[:blocks][block][:owners] = []
    owners_mapping[:blocks][block][:loc_substrs] = []
    owners_mapping[:blocks][block][:counters] = Hash.new
  end

  owners_mapping[:blocks][block][:owners] |= owners if ( (owners) and (owners.size > 0) )
  owners_mapping[:blocks][block][:loc_substrs] |= [loc_substr] if ( (loc_substr) and (loc_substr != "") )
end

def build_owners_mapping_from_file(owners_mapping_file)
  print_and_save_to_logbuffer "\nGenerating owners mapping from file..."
  if (!File.exists?(owners_mapping_file))
    raise "Error: can't find the owners mapping file: " + owners_mapping_file
  end

  file_headers = ["Block", "Location sub string", "Owners"]
  default_block = "FULLCHIP"

  owners_mapping = Hash.new
  owners_mapping[:default_block] = default_block

  CSV.foreach(owners_mapping_file, :headers => true) do |row|
    if (!row.nil?)
      if ( (row.headers.size != 3) or (row.fields.size != 3) or (row.headers != file_headers) )
        raise "Error in owners mapping file syntax: #{owners_mapping_file}"
      end
      
      data_hash = Hash[row.headers[0..-1].zip(row.fields[0..-1])]
      block = data_hash[file_headers[0]]
      loc_substr = data_hash[file_headers[1]]
      owners = data_hash[file_headers[2]]
      
      if ((!block) or (block == ""))
        raise "Bad block name at line: #{row.fields.to_s}"
      end
      if (owners)
        owners = owners.split(",")
      end
      
      add_owners_mapping(block, loc_substr, owners, owners_mapping)
    end
  end

  if ( (owners_mapping[:blocks].has_key?(default_block)) and (owners_mapping[:blocks][default_block][:owners].size > 0) )
    owners_mapping[:default_owners] = owners_mapping[:blocks][default_block][:owners]
  else
    raise "Error: default block #{default_block} owners not defined. Need these integrators to cc all the emails to."
  end

  return owners_mapping
end

def build_messages_to_be_sent(missing_counters_report, owners_mapping, coho_path, alps_formulas_path)
  print_and_save_to_logbuffer "\nBuilding email messages to be sent..."
  messages = []
  
  # For each counter, find the blocks it's used by
  missing_counters_report.each do |counter_name, counter_datahash|
    counter_owner_found = false
    
    counter_datahash[:location_info].each do |location|
      owners_mapping[:blocks].each do |block, block_obj|
        block_obj[:loc_substrs].each do |loc_substr|
          if (/#{loc_substr}/.match(location))  # This counter belongs to the block
            block_obj[:counters][counter_name] = counter_datahash
            counter_owner_found = true
          end
        end
      end
    end
    
    if (not counter_owner_found)  # Add it to the default block
      owners_mapping[:blocks][owners_mapping[:default_block]][:counters][counter_name] = counter_datahash
    end 
  end

  # Create message per block owners
  owners_mapping[:blocks].each do |block, block_obj|
    if (block_obj[:counters].size > 0)  # There is at least one missing counter for this block 
      message = Hash.new
      message[:owners] = block_obj[:owners] | owners_mapping[:default_owners]
      message[:subject] = "ALPS missing counters automatic report (#{block})"
  
      message[:content] = "Hello,\n" +
                          "This is an automatic email detailing the current counters which are used by ALPS formulas but don't exist in Keiko of latest regression.\n" +
                          "The below counters are the ones relevant for you (#{block}).\n" +
                          "Also, attached is the full list of missing counters with info about the locations (tab delimited table file you can open in Excel).\n" +
                          "\n\nCounter_Name\tTotal_Event_Cost[pF]\n"
#                          "\n\nCounter_Name\tTotal_Event_Cost[pF]\tLocation Info\n"
      block_obj[:counters].each do |counter_name, counter_datahash|
#        message[:content] += counter_datahash[:raw_counter_data_line]
        message[:content] += counter_name + "\t" + counter_datahash[:total_ec] + "\n"
      end

      message[:content] +=  "\n\n\nKeiko path that was used:\n#{coho_path}\n" +
                            "ALPS formulas path that was used:\n#{alps_formulas_path}\n"
  
      messages << message
    end
  end

  return messages
end

def send_messages(messages, missing_counters_report_file)
  missing_counters_report_file_unzipped = missing_counters_report_file[/(.+)\.gz$/, 1]
  if ($execute_commands)
    %x[gunzip #{missing_counters_report_file}]
    sleep(5)
  end

  messages.each do |message|
    print_and_save_to_logbuffer "\nSending email to #{message[:owners].to_s}"
    mailing_list = message[:owners].join(" ")
    email_commandline = "echo \"#{message[:content]}\" | mail #{mailing_list} -s \"#{message[:subject]}\" -a #{missing_counters_report_file_unzipped}"
    print_and_save_to_logbuffer email_commandline
    if ($execute_commands)
      %x[#{email_commandline}]
    end
  end

  if ($execute_commands)
    %x[gzip #{missing_counters_report_file_unzipped}]
  end
end

def main_script
  time = Time.now
  time_stamp = time.strftime("%y%m%d_%H%M%S")

  coho_path = nil
  trace = "/nfs/iil/proj/mpgarch/skl_pwer_01/keiko_related/microbenchmarks/MicroBenchmarks_skl_pv_from_lev/skl_pv_fma_512bits_st_ver1_0_4/skl_pv_fma_512bits_st_ver1_0_4"
  alps_path = nil
  alps_formulas_path = nil
  owners_mapping_file = nil
  output_dir = nil

  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename(__FILE__)} [knobs]"
    opts.separator ""
    opts.separator "Specific knobs:"
  
    opts.on("--coho_path VALUE", String, "Coho path.") do |value|
      coho_path = value
    end

    opts.on("--trace VALUE", String, "Trace to run on Coho. Doesn't matter which trace since we just check the presence of counters in the stats file.") do |value|
      trace = value
    end

    opts.on("--alps_path VALUE", String, "ALPS scripts path. If ommited, the scripts under the Coho repository will be used.") do |value|
      alps_path = value
    end

    opts.on("--alps_formulas_path VALUE", String, "ALPS formulas path. If ommited, the formulas under the Coho repository will be used.") do |value|
      alps_formulas_path = value
    end

    opts.on("--owners_mapping_file VALUE", String, "The owners mapping config file path. If ommited, the file under the ALPS config dir under the Coho repository will be used.") do |value|
      owners_mapping_file = value
    end
  
    opts.on("--output_dir VALUE", String, "Output directory. Here the script will create its runtime files as well as the log file.") do |value|
      output_dir = value
    end

    opts.on("--[no-]delete_stat_file", "Delete the stat file after execution (to save space).") do |value|
      $delete_stat_file = value
    end

    opts.on("--[no-]execute_commands", "NO - Sets the flow to only print the command lines and not execute them") do |value|
      $execute_commands = value
    end

    # This displays the help screen, all programs are
    # assumed to have this option.
    opts.on( '-h', '--help', 'Display this screen' ) do
      print_and_save_to_logbuffer opts
      exit
    end
  end
  
  optparse.parse!

  raise "Bad output_dir" if ((!output_dir) or (output_dir == ""))
  raise "Bad coho_path" if ((!coho_path) or (coho_path == ""))
  
  if (!alps_path)
    alps_path = "#{coho_path}/bin/ALPS"
  end
  if (!alps_formulas_path)
    alps_formulas_path = "#{coho_path}/bin/ALPS/formulas/skl_golden_cdr0b/formulas/formulas_file_list.txt"
  end
  if (!owners_mapping_file)
    owners_mapping_file = "#{coho_path}/bin/ALPS/config/skl/owners_mapping_for_missing_counters_report.csv"
  end

  stat_file_path = run_keiko(coho_path, trace, output_dir, time_stamp)
  missing_counters_report_file = run_alps(alps_path, alps_formulas_path, stat_file_path, output_dir, time_stamp)
  missing_counters_report = read_missing_counters_report(missing_counters_report_file)
  owners_mapping = build_owners_mapping_from_file(owners_mapping_file)
  messages = build_messages_to_be_sent(missing_counters_report, owners_mapping, coho_path, alps_formulas_path)
  send_messages(messages, missing_counters_report_file)

  if ($delete_stat_file and $execute_commands)  # Delete the stats file to save space
    %x[rm -rf #{stat_file_path}]
  end

  log_file_name = "#{output_dir}/missing_counters_report_script_#{time_stamp}.log"
  print_and_save_to_logbuffer "Writing log to #{log_file_name}"
  File.open(log_file_name, "w") do |f|
    f.write($logbuffer)
    f.flush
    f.close
  end
  print_and_save_to_logbuffer "Finished!"
  send_log_to_admin

end

if ($0 == __FILE__)
  begin
    main_script
  rescue Exception => e
    print_and_save_to_logbuffer "Error occured:\n#{e.message}"
    send_log_to_admin
    puts "Finished!"
  end
end
