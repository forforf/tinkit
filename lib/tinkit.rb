# Note on Structure
#   I prefer that my dependencies be explicitly called by the "dependee".
#   In other words, if I have a class Foo that depends on Bar, I would have
#   the file foo.rb look like this:
#
#   require 'bar'
#   class Foo
#   end
#
#   However, I also don't want to put everything in a top level path just so I
#   have cleaner require statements.  But I really dislike the 
#   require File.join(File.expand_path(File.dirname(__FILE__)), 'bar')  syntax though
#   functionally it provides the expansion that I like.
#
#   My compromise is to have a helper called from the top level file that maps
#   the directories of my code structure to an easy to remember method.
#   For example if my project was Foobar with class Foo requiring file bar, that 
#   provided Baz functionality (found in the lib/baz/ directory of my project), I'd have:
#
#   require Foobar.baz 'bar'
#   class Foo
#   end
#
#   Not as clean but pretty close, and with the following benefits:
#   - Each file can reference its dependencies explicitly. Great for testing, and invaluable for debugging
#   - Changes to the directory structure are easy to implement and don't require any changes to
#     existing codebase (except for the require helper)
#   - Fairly easy to read
#

#require helper for cleaner require statements
$LOAD_PATH << File.expand_path( File.dirname(__FILE__) )
require 'helpers/require_helper'

#require File.join(File.expand_path(File.dirname(__FILE__)), 'helpers/require_helper')

require Tinkit.lib 'tinkit_node_factory'

module Tinkit
end

