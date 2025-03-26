# lint_check.tcl
# vivado -mode batch -nolog -nojournal -source lint_check.tcl

# clean temp files
proc clean_temp_files {} {
    # delete temp files
    foreach pattern {
        *.pb
        xsim.dir
    } {
        foreach file [glob -nocomplain -- $pattern] {
            file delete -force $file
        }
    }
    
    # delete xsim.dir
    if {[file exists xsim.dir]} {
        file delete -force xsim.dir
    }
}

# find files list function
proc find_hdl_files { base_dir } {
    set extensions {.v  .sv .vhd}
    set file_list [list]
    proc scan_rec { dir } {
        set files {}
        foreach subdir [glob -nocomplain -directory $dir -type d *] {
            set files [concat $files [scan_rec $subdir]]
        }
        foreach file [glob -nocomplain -directory $dir -type f *] {
            lappend files $file
        }
        return $files
    }
    foreach path [scan_rec $base_dir] {
        set ext [string tolower [file extension $path]]
        if {$ext in $extensions} {
            lappend file_list $path
        }
    }
    return $file_list
}

# set source dir and log dir
set src_dir "."      
set log_dir "./logs" 

# create log dir
file mkdir $log_dir

# find all hdl files
set all_files [find_hdl_files $src_dir]

if {[llength $all_files] == 0} {
    puts "no source file"
    exit 1
}

# set check command
set check_cmds {
    ".v"   {xvlog -nolog --incr}
    ".sv"  {xvlog -nolog -sv}
    ".vhd" {xvhdl -nolog}
}

# Initialize counters
set total 0
set warnings 0
set errors 0

# start check
foreach file $all_files {
    incr total
    set ext [string tolower [file extension $file]]
    set log_file [file join $log_dir "[file tail $file].log"]
    
    puts "checking: [file normalize $file]"
    
    if {![dict exists $check_cmds $ext]} {
        puts "skip: $ext"
        continue
    }
    
    set cmd [concat [dict get $check_cmds $ext] [list $file]]
    
    if {[catch {
        set output [exec {*}$cmd 2>@1]
        set status 0
    } error]} {
        set status 1
        set output $error
    }
    
    # Determine if log needs to be written
    set write_log 0
    if {$status != 0} {
        incr errors
        set write_log 1
        puts "  Error found (please check $log_file)"
        # Extract first three lines from output
        set lines [split $output "\n"]
        set first_three [lrange $lines 0 2]
        puts " | [join $first_three " | "]"
    } else {
        if {[regexp -nocase {warning} $output]} {
            incr warnings
            set write_log 1
            puts "  Warning found (please check $log_file)"
        } else {
            puts "lint checking pass"
        }
    }
    
    # Write log only if needed
    if {$write_log} {
        set fid [open $log_file w]
        puts $fid $output
        close $fid
    }
}

# clean temp files
clean_temp_files

puts "\nCheck finish, log save to :$log_dir"
puts "Total files checked: $total"
puts "Files with errors: $errors"
puts "Files with warnings: $warnings"

# Return error code if any errors were found, ci will fail
if {$errors > 0} {
    exit 1
}
exit 0
