#require 'rbconfig'
require 'capsule/autoimport'

# A module which is an instance of the Capsule class encapsulates in its scope
# the top-level methods, top-level constants, and instance variables defined in
# a ruby script file (and its subfiles) loaded by a ruby program. This allows
# use of script files to define objects that can be loaded into a program in
# much the same way that objects can be loaded from YAML or Marshal files.
#
# See intro.txt[link:files/intro_txt.html] for an overview.
#
class Capsule < Module

  #DLEXT = Config::CONFIG['DLEXT']

  # Ruby script extensions to automatically try when searching for
  # a script on the load_path.

  SUFFIXES = ['.rb', '.rbs'] #, '.rbw', '.so', '.bundle', '.dll', '.sl', '.jar']

  # The script file with which the import was instantiated.

  attr_reader :main_file

  # The directory in which main_file is located, and relative to which
  # #load searches for files before falling back to Kernel#load.
  #attr_reader :dir

  # An array of paths to search for scripts. This has the same
  # semantics as <tt>$:</tt>, alias <tt>$LOAD_PATH</tt>, except
  # that it is local to this script. The path of the current
  # script is added automatically.

  attr_reader :load_path

  # A hash that maps <tt>filename=>true</tt> for each file that has been
  # required locally by the script. This has the same semantics as <tt>$"</tt>,
  # alias <tt>$LOADED_FEATURES</tt>, except that it is local to this script.

  attr_reader :loaded_features

  # As with #new but will search Ruby's $LOAD_PATH first.
  # This will also try `.rb` extensions, like require does.

  def self.load(main_file, options=nil, &block)
    file = nil
    $LOAD_PATH.each do |path|
      file = File.join(path, main_file)
      break if file = File.file?(file)
      break if file = Dir.glob(file + '{' + SUFFIXES.join(',') + '}').first
    end
    new(file || main_file, options=nil, &block)
  end

  # Creates new Capsule, and loads _main_file_ in the scope of the script. If a
  # block is given, the script is passed to it before loading from the file, and
  # constants can be defined as inputs to the script.

  def initialize(main_file, options=nil, &block)
    options ||= {}

    @main_file       = File.expand_path(main_file)

    @load_path       = options[:load_path] || []
    @loaded_features = options[:loaded_features] || {}

    @extend          = true  # default
    @extend          = options[:extend] if options.key?(:extend)

    ## add script's path to load_path
    ## TODO: should we be doing this?
    @load_path |= [File.dirname(@main_file)]

    ## if @extend (the default) module extends itself
    extend self if @extend

    module_eval(&block) if block

    load_in_module(main_file)
  end

  # Lookup feature in load path.

  def load_path_lookup(feature)
    paths = File.join('{' + @load_path.join(',') + '}', feature + '{' + SUFFIXES + '}')
    files = Dir.glob(paths)
    match = files.find{ |f| ! @loaded_features.include?(f) }
    return match
  end

  # Loads _file_ into the capsule. Searches relative to the local dir, that is,
  # the dir of the file given in the original call to
  # <tt>Capsule.load(file)</tt>, loads the file, if found, into this Capsule's
  # scope, and returns true. If the file is not found, falls back to
  # <tt>Kernel.load</tt>, which searches on <tt>$LOAD_PATH</tt>, loads the file,
  # if found, into global scope, and returns true. Otherwise, raises
  # <tt>LoadError</tt>.
  #
  # The _wrap_ argument is passed to <tt>Kernel.load</tt> in the fallback case,
  # when the file is not found locally.
  #
  # Typically called from within the main file to load additional sub files, or
  # from those sub files.

  def load(file, wrap = false)
    file = load_path_lookup(feature)
    return super unless file
    load_in_module(file) #File.join(@dir, file))
    true
  rescue MissingFile
    super
  end

  # Analogous to <tt>Kernel#require</tt>. First tries the local dir, then falls
  # back to <tt>Kernel#require</tt>. Will load a given _feature_ only once.
  #
  # Note that extensions (*.so, *.dll) can be required in the global scope, as
  # usual, but not in the local scope. (This is not much of a limitation in
  # practice--you wouldn't want to load an extension more than once.) This
  # implementation falls back to <tt>Kernel#require</tt> when the argument is an
  # extension or is not found locally.
  #
  #--
  # TODO: Should this be using #include_script instead?
  #++

  def require(feature)
    file = load_path_lookup(feature)
    return super unless file
    begin
      @loaded_features[file] = true
      load_in_module(file)
    rescue MissingFile
      @loaded_features[file] = false
      super
    end
  end

  # Checks the class of each +mods+. If a String, then calls #include_script,
  # otherwise behaves like normal #include.

  def include(*mods)
    mods.reverse_each do |mod|
      case mod
      when String
        include_script(mod)
      else
        super(mod)
        extend self if @extend
      end
    end
  end

  # Create a new Capsule for a script and include it into the current capsule.

  def include_script(file)
    include self.class.new(file, :load_path=>load_path, :loaded_features=>loaded_features, :extend=>false)
  rescue Errno::ENOENT => e
    if /#{file}$/ =~ e.message
      raise MissingFile, e.message
    else
      raise
    end
    extend self if @extend
  end

  # Loads _file_ in this module's context. Note that <tt>\_\_FILE\_\_</tt> and
  # <tt>\_\_LINE\_\_</tt> work correctly in _file_.
  # Called by #load and #require; not normally called directly.

  def load_in_module(file)
    module_eval(IO.read(file), File.expand_path(file))
  rescue Errno::ENOENT => e
    if /#{file}$/ =~ e.message
      raise MissingFile, e.message
    else
      raise
    end
  end

  # Give inspection of Capsule with script file name.

  def inspect # :nodoc:
    "#<#{self.class}:#{main_file}>"
  end

  # Raised by #load_in_module, caught by #load and #require.

  class MissingFile < ::LoadError; end

end

