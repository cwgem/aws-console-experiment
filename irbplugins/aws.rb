require 'aws-sdk'

# Function to print a flex table which pads values that are
# less in length than the longest value for the column
#
# headers = array of headers
# values = array of array of values
#
# header count must = value count of course!
#
# returns witchcraft
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

class AwsAccess
  attr_accessor :ec2

  def initialize()
    if File.exists? "#{ENV['HOME']}/.ec2/aws_config.yaml"
      # This is for working with IRB, so I'll let IRB present
      # the exceptions for the user to check into
      config_data = YAML.load(File.read("#{ENV['HOME']}/.ec2/aws_config.yaml"))
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

  def list_regions()
    @ec2.regions.map(&:name)
  end

  def switch_region(region)
    @ec2 = AWS::EC2.new(:ec2_endpoint => "ec2.#{region}.amazonaws.com")
  end

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

  def start_instance(ami_id, type, key = @default_key, group = @default_security_group, count = 1)
    @ec2.instances.create(
      :image_id => ami_id,
      :instance_type => type,
      :count => count,
      :security_groups => group,
      :key_name => key
    )
  end

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

  def terminate_instance(id)
    AWS::EC2::Instance.new(id).terminate
  end

end

$amazon = AwsAccess.new()
