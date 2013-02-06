## Introduction ##

This project is meant to be a proof of concept for using irb to create work flow specific shells. The primary inspiration for this was the [Rails Console](http://guides.rubyonrails.org/command_line.html#rails-console), a console for rails oriented work flows. In the case the work flow I set to create a console for was that of the [Amazon AWS](http://aws.amazon.com/documentation/). To provide an API interface to AWS, the [Ruby AWS SDK](http://aws.amazon.com/documentation/sdkforruby/) was utilized. This console was developed for my specific work flow, creating a proxy to the rather large and complicated API. I just focus on what I need to for common tasks, and add features as I require them. This makes it very flexible.

## Requirements ##

1. Ruby 1.9
2. aws-sdk parseconfig gem
3. Existence

## Why A Console? ##

I find that using a REPL such as irb allows for a more flexible development process. If I find a script is laking functionality, I normally have to go back and adjust the scripts and rerun the program. With irb however I can decide whether or not I want to fix it in the script, or if it's just a one time issue that I can work around. Take for example:

```ruby
  def terminate_instance(id)
    AWS::EC2::Instance.new(id).terminate
  end
```

Here is some code used to terminate an instance. However when working in the console I realized I needed to terminate multiple instances. One way would be to adjust the code, most likely using the [splat operator](http://en.wikibooks.org/wiki/Ruby_Programming/Syntax/Method_Calls#Variable_Length_Argument_List.2C_Asterisk_Operator). However since I was in irb I could simply use ruby to work around that quickly:

```
['i-16409b66','i-f6ed3786'].each { | id | $amazon.terminate_instance id }
```

No need to stop what I'm doing in the REPL to go back and fix the script. If I need to later I can fix it in the script as well, when I'm done doing what I need to do. I also get the ability to quickly inspect objects (even more so if using [pry](http://pryrepl.org/)). 

## How Does It Work? ##

The architecture behind it is really not that complicated. In essence I have a simple `~/.irbrc` file like so:

```ruby
def load_plugin(name)
  plugin_path = "#{ENV['HOME']}/irbplugins/#{name}.rb"
  if File.exists? plugin_path
    load plugin_path
  else
    raise "Could not locate plugin #{plugin_path}"
  end
end
```

Just a simple command to load a "plugin" was is just a simple ruby script with code. In my case I put my scripts in a folder called `~/irbplugins`. I chose this route because I can't guarantee a plugin will be available all the time, so I don't want irb trying to blindly load it. Within that `~/irbplugins` folder is a script that's called `aws.rb` which has the main functionality.

## Usage ##

### Setup ###

To use this in an irb session you just need to do:

```load_plugin "aws"```

As for the script itself (`~/irbplugins/aws.rb`), the file is rather large (the reason why I'm posting it to GitHub) but I'll go over the main functionality piece by piece:

```ruby
  attr_accessor :ec2

  def initialize()
    if File.exists? "#{ENV['HOME']}/.ec2/aws.config"
      # This is for working with IRB, so I'll let IRB present
      # the exceptions for the user to check into
      config_data = ParseConfig.new("#{ENV['HOME']}/.ec2/aws.config")
      key = config_data['access_key_id']
      secret = config_data['secret_access_key']

      @default_key = config_data['default_key']
      @default_security_group = config_data['default_security_group']
    else
      # Except for authentication, catch that before AWS does
      raise SecurityError.new("No AWS authentication found!")
    end

    AWS.config({ :access_key_id => key, :secret_access_key => secret })
    @ec2 = AWS::EC2.new()
  end

```

This is all wrapped in a class called `AwsAccess`. The initializer does basic setup for authentication and configuration, and in this case give me an ec2 instance variable to work with. Notice I've made it `attr_accessor` which let's me use irb to play around with the various EC2 methods and variables for experimentation. 

The configuration is read from an `aws.config` file in `~/.ec2`. It looks like this:

```
access_key_id = my_key_id
secret_access_key = my_key_secret
default_key = MyGroup
default_security_group = MyGroup
```
(Sorry to let down those who were waiting for me to expose my AWS creds ;)

The configuration file could be anything, but I've find that I use a specific key and group for testing a lot, so I've added it in as a default. You can choose not to and specify a specific key if you want.

### Working With Regions ###

I found the switching between regions to be rather cumbersome. With that in mind I created basic methods to work with regions:

```ruby
  def list_regions()
    @ec2.regions.map(&:name)
  end

  def switch_region(region)
    @ec2 = AWS::EC2.new(:ec2_endpoint => "ec2.#{region}.amazonaws.com")
  end
```

Here I don't use a `puts` or any sort of output method, as I know IRB will do that work for me. That's fine as I get what I need. Once I have the region I need I can use the `switch_region` method to easily switch. This in essence rebuilds the `@ec2` instance variable with the region I want in question. 

```
1.9.3p374 :016 > $amazon.list_regions
 => ["eu-west-1", "sa-east-1", "us-east-1", "ap-northeast-1", "us-west-2", "us-west-1", "ap-southeast-1", "ap-southeast-2"]
1.9.3p374 :017 > $amazon.switch_region('us-west-1')
 => <AWS::EC2>
```

Here's an example where I list out the regions and decide I want to work with the US west region as I live on the west coast (US east is the default). 

### Listing Instances ###

Next is the listing of instances. If you've ever seen the output of `ec2-describe-instances` for the Amazon CLI tools, it's extremely detailed:

```
PROMPT> ec2-describe-instances

RESERVATION     r-1a2b3c4d      111122223333    my-security-group
INSTANCE        i-1a2b3c4d      ami-1a2b3c4d    ec2-67-202-51-223.compute-1.amazonaws.com       ip-10-251-50-35.ec2.internal    running gsg-keypair     0               t1.micro        YYYY-MM-DDTHH:MM:SS+0000        us-west-2a      aki-1a2b3c4d                    monitoring-disabled     184.73.10.99    10.254.170.223                  ebs                                     paravirtual     xen     ABCDE1234567890123      sg-1a2b3c4d     default false   
BLOCKDEVICE     /dev/sda1       vol-1a2b3c4d    YYYY-MM-DDTHH:MM:SS.SSSZ        true    
BLOCKDEVICE     /dev/sdb        vol-2a2b3c4d    YYYY-MM-DDTHH:MM:SS.SSSZ        true    
TAG     instance        i-1a2b3c4d      Name    Linux
RESERVATION     r-2a2b3c4d      111122223333    another-security-group
INSTANCE        i-2a2b3c4d      ami-2a2b3c4d    ec2-67-202-51-223.compute-1.amazonaws.com       ip-10-251-50-35.ec2.internal    running gsg-keypair     0               t1.micro        YYYY-MM-DDTHH:MM:SS+0000        us-west-2c                      windows monitoring-disabled     50.112.203.9    10.244.168.218                  ebs                                     hvm     xen     ABCDE1234567890123      sg-2a2b3c4d     default false   
TAG     instance        i-2a2b3c4d      Name    Windows
```

I've never needed this much information. With that in mind I created a method to give me a more simplistic view of my instances:

```
  def describe_instances()
    # Reduce API call usage
    # http://aws.typepad.com/aws/2012/01/how-collections-work-in-the-aws-sdk-for-ruby.html

    headers = ["Instance ID", "Type", "AMI ID", "Status", "IP Address", "Host", "Security Groups"]
    values = []

    AWS.memoize do
      @ec2.instances.each do | i |
        values << [i.id, i.instance_type, i.image_id, i.status, i.ip_address, i.dns_name, i.security_groups.map(&:name).join(" ")]
      end
    end

    print_flex_table(headers, values)
  end
```

In this case though I wanted a more easy to read view versus an array dump that irb would give me, so I created a function to print a flexible table:

```ruby
def print_flex_table(headers, values)
  raise ArgumentError.new('Table header and value count does not match') if headers.length != values[0].length

  column_lengths = []

  # figure out what the longest string is between the
  # headers and values for calculating padding
  headers.each_with_index do | header, index |
    column_lengths[index] = header.length

    values.each do | value |
      # not really necessary, but makes the next few lines easier to read
      value_length = value[index].to_s.length
      column_lengths[index] = value_length if value_length > column_lengths[index]
    end
  end

  # now run through them again with our calculated lengths
  headers.each_with_index do | header, index |
    print header.ljust( column_lengths[index] )
    print (index < headers.length - 1) ? " | " : "\n"
  end

  # Puts a divider between the headers and values. It calculates the
  # print width based on the longest calculated column length + 3
  # characters for the " | " separator (save the last value)
  puts "-" * ( column_lengths.inject(:+) + ( ( headers.length - 1 ) * 3 ) )

  values.each do | value |
    value.each_with_index do | item,index |
      print item.to_s.ljust( column_lengths[index] )
      print (index < value.length - 1 ) ? " | " : "\n"
    end
  end

  # otherwise IRB shows the values array dump as the
  # return of a function is the returned value of the
  # last evaluated expression
  return

end
```

This is basically a function to print a table with column widths that adjust to the length of the longest column value. So I get something like this:

```
Instance ID | Type     | AMI ID       | Status  | IP Address     | Host                                       | Security Groups
----------------------------------------------------------------------------------------------------------------------------------------------------
i-f0f82380  | m1.large | ami-xxxxxxxx | running | xxx.xx.xxx.xx  | ec2-xx-xxx-xxx-xx.compute-1.amazonaws.com  | MyGroup
i-16409b66  | m1.large | ami-xxxxxxxx | running | xx.xxx.xxx.xxx | ec2-xx-xxx-xxx-xxx.compute-1.amazonaws.com | MyGroup
i-f6ed3786  | m1.large | ami-xxxxxxxx | pending | xx.xxx.xxx.xx  | ec2-xx-xxx-xxx-xx.compute-1.amazonaws.com  | MyGroup2
 => nil
1.9.3p374 :075 > ['i-16409b66','i-f6ed3786'].each { | id | $amazon.terminate_instance id }
 => ["i-16409b66", "i-f6ed3786"]
1.9.3p374 :076 > $amazon.describe_instances
Instance ID | Type     | AMI ID       | Status        | IP Address     | Host                                       | Security Groups
----------------------------------------------------------------------------------------------------------------------------------------------------------
i-f0f82380  | m1.large | ami-xxxxxxxx | running       | xxx.xx.xxx.xx  | ec2-xxx-xx-xxx-xx.compute-1.amazonaws.com  | MyGroup
i-16409b66  | m1.large | ami-xxxxxxxx | shutting_down | xx.xxx.xxx.xxx | ec2-xx-xxx-xxx-xxx.compute-1.amazonaws.com | MyGroup
i-f6ed3786  | m1.large | ami-xxxxxxxx | shutting_down | xx.xxx.xxx.xx  | ec2-xx-xxx-xxx-xx.compute-1.amazonaws.com  | MyGroup2

```

Notice how the Status column expands to fit the new shutting_down status. Later on I may make a different method to display output differently (for example to check volumes attached to a device), but I can cross that road when I get to it.

### Starting Instances ###

Here I've made a method to start instances based on a specific ami and type. I've allowed the ability to change counts, security groups, and keys as necessary. 

```ruby
  def start_instance(ami_id, type, count = 1, group = @default_security_group, key = @default_key )
    @ec2.instances.create(
      :image_id => ami_id,
      :instance_type => type,
      :count => count,
      :security_groups => group,
      :key_name => key
    )
  end
```

However I often find myself thinking "I need another instance like this". For example if I need the same AMI and type but I want to start from scratch or do additional testing in a similar environment while a long process is running. For that I have this method:

```ruby
  def duplicate_instance(id, count=1)
    instance = AWS::EC2::Instance.new(id)
    key_name = instance.key_name || @default_key

    @ec2.instances.create(
      :image_id => instance.image_id,
      :instance_type => instance.instance_type,
      :count => count,
      :security_groups => instance.security_groups.map(&:name).join(" "),
      :key_name => key_name
    )
  end
```

Here I simply pass it the ami id of the instance I want to duplicate, and it looks it up and creates a new instance based on basic properties of the original instance. 

### Instance Termination ###

```ruby
  def terminate_instance(id)
    AWS::EC2::Instance.new(id).terminate
  end
```

Pretty basic method that you give it an idea and it terminates the instance. As mentioned before this can probably be adjusted to use the splat operator so I terminate multiple instances.

## Conclusion ##

This concludes a look into creating a work flow specific console using irb. There's probably a lot more I can add, but the nice thing is I can experiment in the REPL when that time comes, and adjust my script as necessary. When that's done it's as simple as:

```
1.9.3p374 :077 > load_plugin "aws"
```

If I'm really worried about state I can reload irb as necessary. 

## Author ##

[@cwgem](https://www.twitter.com/cwgem) (Chris White) on Twitter
