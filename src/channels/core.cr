module Channels
  extend self
  
  def pipe(input : Channel(A), output : Channel(A), close_when_done : Bool = true) forall A
    pipe(input, ->(a : A){ a }, output, close_when_done)
  end
  
  def pipe(input : Channel(A), f : Proc(A, B), output : Channel(B), close_when_done : Bool = true) forall A, B
    spawn do
      while elem = input.receive
        output.send f.call(elem)
      end
      output.close if close_when_done
    end
  end
  
  def multiplex(inputs : Array(Channel(A)), output : Channel(A), close_when_done : Bool = true) forall A
    multiplex(inputs, ->(a : A){ a }, output, close_when_done)
  end
  
  def multiplex(inputs : Array(Channel(A)), f : Proc(A, B), output : Channel(B), close_when_done : Bool = true) forall A, B
    spawn do
      finish = Channel(Bool).new
      inputs.each do |input|
        spawn do
          while elem = input.receive
            output.send f.call(elem)
          end
          finish.send true if close_when_done
        end
      end

      if close_when_done
        count = 0
        while count < inputs.size
          count += 1 if finish.receive
        end
        output.close
      end
    end
  end
  
  def tee(input : Channel(A), outputs : Array(Channel(A)), close_when_done : Bool = true) forall A
    tee(input, ->(a : A){ a }, outputs, close_when_done)
  end
  
  def tee(input : Channel(A), f : Proc(A, B), outputs : Array(Channel(B)), close_when_done : Bool = true) forall A, B
    spawn do
      while elem = input.receive
        outputs.each { |output| output.send f.call(elem) }
      end
      outputs.each { |output| output.close } if close_when_done
    end
  end
  
  def distribute(input : Channel(A), outputs : Array(Channel(A)), close_when_done : Bool = true) forall A
    distribute(input, ->(a : A){ a }, outputs, close_when_done)
  end
  
  def distribute(input : Channel(A), f : Proc(A, B), outputs : Array(Channel(B)), close_when_done : Bool = true) forall A, B
    spawn do
      while elem = input.receive
        outputs.sample.send f.call(elem)
      end
      outputs.each { |output| output.close } if close_when_done
    end
  end
  
  def round_robin(input : Channel(A), outputs : Array(Channel(A)), close_when_done : Bool = true) forall A
    round_robin(input, ->(a : A){ a }, outputs, close_when_done)
  end
  
  def round_robin(input : Channel(A), f : Proc(A, B), outputs : Array(Channel(B)), close_when_done : Bool = true) forall A, B
    spawn do
      index = 0
      while elem = input.receive
        outputs[index].send f.call(elem)
        index = index.succ % outputs.size
      end
      outputs.each { |output| output.close } if close_when_done
    end
  end
  
  def async(f : A -> B): A -> Channel(B) forall A, B
    Proc(A,Channel(B)).new do |a|
      b = Channel(B).new
      spawn { b.send f.call(a) }
      return b
    end
  end
  
  def lift(f : A -> B): Channel(A) -> Channel(B) forall A, B
    Proc(Channel(A), Channel(B)).new do |a|
      b = Channel(B).new
      Channels.pipe(a, f, b)
      return b
    end
  end
end