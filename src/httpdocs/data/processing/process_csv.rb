require 'json'
require 'digest'
#category
#  key
#  src
#  hash # Doesn't appear to be used?
#  sub: categories
#  descr
#  url
#  values: values

#value
#  val
#	 year
require 'csv'

class CategoryList
  
  attr_accessor :categories
  
  def initialize
    @categories = []
  end
  
  def all
    @categories
  end
  
  def subtotal(year)
    vals = all.collect{ |c| c.values.find_by_year(year) }.flatten
    vals.inject(0){ |sum, this_val| sum += this_val.val}
  end
  
  def find(attrs)
    c = categories.select{ |elt| elt.match?(attrs) }.first
    if c.nil?
      c = Category.new(attrs)
      categories << c
    end
    c
  end
  
  def any?
    length > 0
  end
  
  def length
    categories.length
  end
  
  def to_hash
    all.collect{ |c| c.to_hash }.select{ |h| h }
  end  
end

class Category
  attr_accessor :key, :src, :hash, :categories, :descr, :url, :values
  
  def initialize(attrs = {})
    @key = attrs[:key]
    @descr = attrs[:descr]
    @hash = hashify
    
    @categories = CategoryList.new
    @values = ValueList.new
  end
  
  def hashify
    md5 = Digest::MD5.new
  	md5.update(self.key)
  	md5.update(self.descr) if self.descr
  	md5.hexdigest()
  end
  
  def match?(attrs = {})
    @key == attrs[:key] && @descr == attrs[:desc]
  end
  
  def value(v, r)
    values.add(v, r)
  end
  
  def subcategory(key)
    categories.find(key: key)
  end
  
  def to_hash
    return nil if !categories.any? && !values.values.any?
    ch = categories.to_hash # compute leaves first, give subtotal something to find [jvf]
    if categories.subtotal("2015") > 0
      value(categories.subtotal("2015"), 0)
    end
    {
      key: self.key, 
      src: self.src, 
      hash: self.hash, 
      sub: ch,
      descr: self.descr, 
      url: self.url, 
      values: values.to_hash
    }
  end
  
end

class ValueList
  
  attr_accessor :values
  def initialize
    @values = []
  end
  def length
    values.length
  end
  def add(v, r)
    val = find_by_year("2015").first
    if !val.nil?
      val.val = val.val + v
    else
      val = Value.new
      val.val = v
      val.year = "2015"
      val.row = r
      values << val
    end
  end
  def to_hash
    values.collect{|v| v.to_hash}
  end
  
  
  def find_by_year(y)
    values.select{ |v| v.year == y }
  end
end

class Value
  # We store row for aid in debugging, but elide it for use.
  # [jvf]
  attr_accessor :val, :year, :row
  
  def to_hash
    {
    val: self.val, 
    year: self.year,
    #row: self.row
    }
  end
end

class ProcessCsv
  
  attr_accessor :category
  
  def initialize
    @category = Category.new(key: "Expenses")
  end
  
  def fund_lookup(code)
    case code
    when "1000"
      "General Fund"
    else
      "Fund #{code}"
    end
  end
  
  def dept_lookup(code)
    case code
    when "00"
    	"Non Department"
    when "10"
    	"Mayor & Council"
    when "11"
    	"City Manager"
    when "12"
    	"City Clerk"
    when "13"
    	"City Attorney"
    when "14"
    	"Budget & Evaluation"
    when "15"
    	"Shared Services"
    when "16"
    	"Finance"
    when "17"
    	"Human Resources"
    when "18"
    	"Innovation & Technology"
    when "30"
    	"Charlotte Mecklenburg Police"
    when "31"
    	"Fire"
    when "40"
    	"Aviation"
    when "41"
    	"Charlotte Area Transit System"
    when "42"
    	"Charlotte Department of Transportation"
    when "50"
    	"Solid Waste Services"
    when "60"
    	"Charlotte-Mecklenburg Planning"
    when "61"
    	"Neighborhood & Business Services"
    when "70"
    	"Charlotte Water (formerly Charlotte Mecklenburg Utility Department)"
    when "80"
    	"Engineering & Property Management"
    else
      "Unknown"
    end
  end
  
  def value(v)
    Value.new(year: 2015, val: v)
  end
  
  def dollar_value_in(row)
    row[10].gsub(',','').to_i
  end
  
  def record(c, dollars, row)
    c.value(dollars, row) if dollars > 0    
  end
  
  def transform(file = "expenses.csv")
    CSV.foreach(file).each_with_index do |row, i|
      f = fund_lookup(row[0])
      k = dept_lookup(row[1])
      next if k == "Unknown"
      fund = @category.categories.find(key: f)
      cat = fund.categories.find(key: k)
      subc = cat.subcategory(row[8])
      section = row[7].split('-')[4]
      record(subc, dollar_value_in(row), i)
    end
    @category.to_hash
  end
end
puts JSON.pretty_generate(ProcessCsv.new.transform)
File.open("expenses.json", 'w') {|f| f.write(JSON.generate(ProcessCsv.new.transform)) }