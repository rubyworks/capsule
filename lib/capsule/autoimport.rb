class Module

  const_missing_definition_for_autoimport = lambda do
    #$autoimport_activated = true
    alias const_missing_before_autoimport const_missing

    def const_missing(sym) # :nodoc:
      filename = @autoimport && @autoimport[sym]
      if filename
        mod = Capsule.load(filename)
        const_set sym, mod
      else
        const_missing_before_autoimport(sym)
      end
    end
  end

  # See Kernel#autoimport.
  #
  # TODO: Document this method using meta-programming markup.
  define_method(:autoimport) do |mod, file|
    if @autoimport.empty? #unless $autoimport_activated
      const_missing_definition_for_autoimport.call
    end
    (@autoimport ||= {})[mod] = file
  end
end


module Kernel
  # When the constant named by symbol +mod+ is referenced, loads the script
  # in filename using Capsule.load and defines the constant to be equal to the
  # resulting Capsule module.
  #
  # Use like Module#autoload. However, the underlying opertation is #load rather
  # than #require, because scripts, unlike libraries, can be loaded more than
  # once. See examples/autoscript-example.rb.
  #
  # This method call `Object.autoimport` as defined in Module.
  def autoimport(mod, file)
    Object.autoimport(mod, file)
  end
end

