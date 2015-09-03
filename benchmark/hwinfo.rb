#!/usr/bin/ruby
class String
    def is_i?
       !!(self =~ /^[-+]?[0-9]+$/)
    end
end

class String
  def convert_base(from, to)
    self.to_i(from).to_s(to)
  end
end

dmiinfo = %x(dmidecode --type memory).split("\n")

memtype  = "DDR"
memspeed = "266"
memmodulesize  = "1024"
memmodules = 0
dmiinfo.each do | line |
  fields = line.split(" ")
  if fields[0] == "Type:" && fields[1] != "Unknown"
    memtype = fields[1]
  end
  if (fields[0]  == "Speed:")
    if (fields[1].is_i?)
        memspeed = fields[1]
      end
  end
  if (fields[0]  == "Size:")
    if (fields[1].is_i?)
      memmodulesize = fields[1].to_i
      memmodules = memmodules + 1
    end
  end
end

memsize = memmodulesize * memmodules

cpuspeed = "1.0"
cpucache = "1024"
cpuinfo = %x(cat /proc/cpuinfo).split("\n")
cpufamily = "6"
cpumodel = "4"
cpustepping = "1"
cpuvendor = "GenuineIntel"

cpus = 0
cpuinfo.each do | line |
  fields = line.split(" ")
  if (fields[0] == "cpu")
    if (fields[1] == "MHz")
      cpuspeed = ((fields[3].to_i)/100.0+0.5).to_i/10.0
      cpus = cpus + 1
    end
    if (fields[1] == "family")
      cpufamily = fields[3].to_i
    end
  end
  if (fields[0] == "cache" && fields[1] == "size")
    cpucache = fields[3].to_i
  end
  if (fields[0] == "vendor_id")
    cpuvendor = fields[2]
  end
  if (fields[0] == "stepping")
    cpustepping = fields[2]
  end
  if (fields[0] == "model" && fields[1] == ":")
    cpumodel = fields[2]
  end
end
# get the cpu maximum speed from dmidecode 
dmiinfo = %x(dmidecode --type processor).split("\n")
dmiinfo.each do | line |
  fields = line.split(" ")
  if fields[0] == "Max" && fields[1] != "Speed:"
    cpuspeed = ((fields[3].to_i)/100.0+0.5).to_i/10.0
  end
end


#print "Memtype  = " + memtype.to_s + "\n"
#print "Memspeed = " + memspeed.to_s + "\n"
#print "Memsize  = " + memsize.to_s + "\n"

#print  "Cpuspeed  = " + cpuspeed.to_s +  "\n"
#print  "Cpucache  = " + cpucache.to_s + "\n"
#print  "Cpuvendor = " + cpuvendor + "\n"
#print  "CPUfamily = " + cpufamily.to_s + "\n"
cpuid = cpufamily.to_s.convert_base(10,16) + cpumodel.to_s.convert_base(10,16) + cpustepping.to_s.convert_base(10,16) + "h"
#print "CPUID = " + cpuid + "\n"

vendor = "o"
if (cpuvendor == "GenuineIntel")
  vendor = "i"
end
if (cpuvendor == "AuthenticAMD")
    vendor = "a"
end
osmajorrelease=%x(cat /etc/redhat-release | cut -d "." -f 1 | awk '{print $NF}')
lsftype = vendor+osmajorrelease.chomp+"_"+cpus.to_s+"_"+cpuid+cpuspeed.to_s.gsub(".","")+"_"+memspeed.to_s
#
#        x["lsftype"] = x["cpuvendor"]+x["osmajorrelease"].chomp+"_"+str(int(x["physcores"]))+"_"+x["cpuid"]+x["cpuspeed"]+"_"+x["memspeed"]
#        x["lsftype"] = x["lsftype"].replace(".", "");
#print "LSFtype=" + lsftype+"\n"
print lsftype
