class Article < ActiveRecord::Base
  include ArticlesHelper
  
  has_many :comments
  belongs_to :user
  acts_as_leiden_plus
  
  # has_many :events
  validates_presence_of :content
  
  # validate :must_be_valid_xml
  # validate :must_be_valid_epidoc

  def must_be_valid_xml
    # errors.add_to_base("Content must be valid XML") unless (valid_xml?(content) != nil)
  end

  def must_be_valid_epidoc
    errors.add_to_base("Content must be valid EpiDoc") unless valid_epidoc?(content)
  end
  
  def leiden_plus
    abs = get_abs_from_edition_div(content)
    transformed = xml2nonxml(abs)
    if transformed =~ /^dk\.brics\.grammar\.parser\.ParseException: parse error at character (\d+)/
      transformed + "\n" + parse_exception_pretty_print(abs, $1.to_i)
    else
      transformed
    end
  end
end