#!/usr/bin/expect -f


proc usage {} {
  #send_error "usage: ci_deploy arguments\n"
  set USAGE [puts "
  Remove .htaccess file at the root of a site

  This is a required part off the deploy process sometimes.
  The .htaccess file is needed in the Git repo for dev sites,
  but on the live site we want the .htaccess rules controlled
  by the Apache configs that are stored else where. So, the
  deploy process can call this script after pulling the master
  branch, to delete the unneeded .htaccess file.

  USAGE: remove_htaccess.tcl host wc user pass

  ARGUMENTS:
    host    Host name of the machine you are connecting to with SSH.
    wc      Path to the existing working copy on the remote server
    user    SSH username
    pass    (Optional) SSH password if you don't have SSH keys setup
            for the connection.

  EXAMPLE:
    remove_htaccess.tcl example.com /srv/www/example.com/public_html janesmith

      or

    remove_htaccess.tcl example.com /srv/www/example.com/public_html janesmith EC2wBOEk26.8
  "]
  send_error $USAGE
  exit 1
}

# Display usage rules if no arhuments are defined
if {[llength $argv] == 0} usage

# Arguments that can be passed to this script

# example.com
set HOST [lindex $argv 0]

# /path/to/the/working/copy
set WC [lindex $argv 1]

# username
set USER [lindex $argv 2]

# password
set PASS [lindex $argv 3]

# Check for a valid hostname
if {![regexp {^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$} $HOST] && ![regexp {^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$} $HOST]} {
  puts "ERROR: That is not a valid hostname or IP address."
  usage
}

# Check for a working copy path
if {$WC eq ""} {
  puts "ERROR: You didn't specify the path to your working path."
  usage
}

# Check for a working copy path
if {$USER eq ""} {
  puts "ERROR: You didn't specify a SSH username"
  usage
}

# A decent guess at the default prompt for most users
set prompt "(%|#|\\\$) $"

# Define error codes
set E_NO_SSH      2 ;# can't find a usable SSH on our system
set E_NO_CONNECT  3 ;# failure to connect to remote server (timed out)
set E_WRONG_PASS  4 ;# password provided does not work
set E_WC_NO_EXIST 5 ;# working copy directory doesn't exist
set E_WC_FILE     6 ;# .htaccess file error
set E_UNKNOWN     25 ;# unexpected failure

# Find the SSH binary on our system
if {[file executable /usr/bin/ssh]} {
  set SSHBIN /usr/bin/ssh
} elseif {[file executable /usr/local/bin/ssh]} {
  set SSHBIN /usr/local/bin/ssh
} else {
  send_error "ERROR: Can't find a usable SSH on this system.\n"
  exit $E_NO_SSH
}

# SSH to remote server
spawn $SSHBIN $USER@$HOST
expect {
    # Supply a password if it's provided
    -nocase "Are you sure you want to continue connecting (yes/no)? " { send "yes\r"; exp_continue; }
    -nocase "Password:" { send "$PASS\r"; exp_continue; }
    -nocase "Password for '$USER': " { send "$PASS\r"; }
    -nocase "$USER@$HOST\'s password: " { send "$PASS\r"; }

    # If you get to the prompt, SSH worked without a password,
    # probably, because SSH keys are setup between the machines
    $prompt;
}

# If we are using Git we must move into the working directory before pulling
# Go to the working copy dir
send "cd $WC\r";
expect {
  -nocase "No such file or directory" {
    send "exit\r";
    send_error "\n ERROR: The working copy directory you supplied does not exist \n";
    exit $E_WC_NO_EXIST;
  $prompt;
  }
}
# Pull the latest from Git
send "rm .htaccess\r";
expect {
  -nocase "rm: cannot remove `.htaccess': Permission denied" {
    send "exit\r";
    send_error "\n ERROR: This user does not have permission to delete that file. \n";
    exit $E_WC_NOT_GIT;
  }
  -nocase "rm: cannot remove `.*': No such file or directory" {
    send "exit\r";
    send_error "\n ERROR: That directory does not have a .htaccess file to delete. \n";
    exit $E_WC_NOT_GIT;
  $prompt;
  }
  -re "error:.*" {
    send "exit\r";
    send_error "\n ERROR: Unknown error \n";
    exit $E_GIT_ERROR;
  $prompt;
  }
}

send "exit\r";
expect EOF
