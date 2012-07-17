#!/usr/bin/env python

""" Remove .htaccess file at the root of a site

This is a required part off the deploy process sometimes.
The .htaccess file is needed in the Git repo for dev sites,
but on the live site we want the .htaccess rules controlled
by the Apache configs that are stored else where. So, the
deploy process can call this script after pulling the master
branch, to delete the unneeded .htaccess file.

"""

import os
import argparse
import sys

def delete_file(filepath):
    """Delete a file
    Args:
        filepath: a string of the filepath
    Returns:
        A boolean indicating if the file was deleted
        with errors (1) or without errors (0).
    """
    os.remove(filepath)

def check_file_exits(filepath):
    """Check if the .htaccess file exists
    Args:
        filepath: a string of the filepath
    Returns:
        A boolean indicating if the file exists
    """
    if os.path.isfile(filepath):
        return 0
    else:
        print "There is no .htaccess file here: %s" % str(filepath)
        return 1

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('path')
    args = parser.parse_args()
    path = args.path
    filepath = path + '/.htaccess'

    if not check_file_exits(filepath):
        delete_file(filepath)
        print ".htaccess deleted"
    else:
        sys.exit("Error")

if __name__ == "__main__":
    main()
