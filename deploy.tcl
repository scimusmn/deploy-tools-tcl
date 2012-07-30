#!/usr/bin/expect -f

# This script is based on an original script by Meitar Moscovitz from
# URL : http://maymay.net/blog/2007/06/21/a-better-expect-subversion-post-commit-hook/
# 
# Modified for Science Museum of Minnesota use by bryan kennedy

proc usage {} {
  #send_error "usage: ci_deploy arguments\n"
  set USAGE [puts "
  This script connects to a server using SSH and pulls the latest
  updates from a VCS repository (Git or SVN).

  USAGE: ci_deploy host vcs wc branch user pass

  ARGUMENTS:
    host    Host name of the machine you are connecting to with SSH.
    vcs     Pick your VCS of choice
              git
              svn
    wc      Path to the existing working copy on the remote server
    branch  Git branch to pull
    user    SSH username
    pass    (Optional) SSH password if you don't have SSH keys setup
            for the connection.

  EXAMPLE:
    ci_deploy example.com git /srv/www/example.com/public_html janesmith

      or

    ci_deploy example.com git /srv/www/example.com/public_html janesmith EC2wBOEk26.8
  "]
  send_error $USAGE
  exit 1
}

# Display usage rules if no arhuments are defined
if {[llength $argv] == 0} usage

# Arguments that can be passed to this script

# example.com
set HOST [lindex $argv 0]

# Git or SVN?
set VCS [lindex $argv 1]

# /path/to/the/working/copy
set WC [lindex $argv 2]

# git branch to pull
set GIT_BRANCH [lindex $argv 3]

# username
set USER [lindex $argv 4]

# password
set PASS [lindex $argv 5]

# Check for a valid hostname
if {![regexp {^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$} $HOST] && ![regexp {^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$} $HOST]} {
  puts "ERROR: That is not a valid hostname or IP address."
  usage
}

# Check for a valid VCS choice
if {$VCS eq ""} {
  puts "ERROR: You didn't specify a Version Control System. 'git' or 'svn'"
  usage
}
if {$VCS != "git" && $VCS != "svn"} {
  puts "ERROR: The VCS you specified is not supported. Please choose, git or svn."
  usage
}

# Check for a working copy path
if {$WC eq ""} {
  puts "ERROR: You didn't specify the path to your working path."
  usage
}

# Check for a working copy path
if {$VCS == "git" && $GIT_BRANCH eq ""} {
  puts "ERROR: If using Git you must define the branch to pull."
  usage
}

# Check for a working copy path
if {$USER eq ""} {
  puts "ERROR: You didn't specify a SSH username"
  usage
}

# VCS system names
# :TODO: It would be smart to detect the vcs app path using which
set GIT_STRING "git"
set SVN_STRING "svn"

# A decent guess at the default prompt for most users
set prompt "(%|#|\\\$) $"

# Define error codes
set E_NO_SSH      2 ;# can't find a usable SSH on our system
set E_NO_CONNECT  3 ;# failure to connect to remote server (timed out)
set E_WRONG_PASS  4 ;# password provided does not work
set E_WC_NO_EXIST 5 ;# working copy directory doesn't exist
set E_GIT_ERROR   6 ;# there is something wrong with the remote git server
set E_WC_NOT_GIT  7 ;# working copy not a git repo
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
if {[string compare $VCS $SVN_STRING] == 0} {
  # If using SVN we can update the repo at the same time
  spawn $SSHBIN $USER@$HOST svn update $WC
} elseif {[string compare $VCS $GIT_STRING] == 0} {
  # If Git, just open SSH connection
  spawn $SSHBIN $USER@$HOST 
}
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
if {[string compare $VCS $GIT_STRING] == 0} {
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
  send "git pull origin $GIT_BRANCH \r";
  expect {
    -nocase "fatal: Not a git repository" {
      send "exit\r";
      send_error "\n ERROR: The working copy you supplied is not a Git repository \n";
      exit $E_WC_NOT_GIT;
    }
    -nocase "fatal: The remote end hung up unexpectedly" {
      send "exit\r";
      send_error "\n ERROR: The origin git repo is down. Remote end hung up. \n";
      exit $E_WC_NOT_GIT;
    }
    -re "error:.*" {
      send "exit\r";
      send_error "\n ERROR: Unknown git error \n";
      exit $E_GIT_ERROR;
    }
    $prompt;
  }
  # Checkout all files, in case any local changes have been made.
  # No errors are expected, since Git will just write over local
  # changes with no output.
  send "git checkout . \r"
}

send "exit\r";
expect EOF
