class TranslationLeiden < HGVTransIdentifier  
 
  #created as sub-class of HGVTransIdentifier because it already has the acts_as_translation
 
  def self.xml_to_translation_leiden(content)
    if content.include?("<div")
      #wrap in <body> tag only so that the sugar grammer can transform 
      #assume <div> and <p> both provided
      wrapped_content = "<body xmlns:xml=\"http://www.w3.org/XML/1998/namespace\">" + content + "</body>"
      #call to convert xml to leiden
      transformed = HGVTransIdentifier.xml2nonxml(wrapped_content)
      # user xml content included <div> so no need to slice after converted
    else
      if content.include?("<p>")
        #wrap in <body> and <div> tags so that the sugar grammer can transform 
        #assume <div> not provided and <p> was provided
        wrapped_content = "<body xmlns:xml=\"http://www.w3.org/XML/1998/namespace\"><div xml:lang=\"en\" type=\"translation\" xml:space=\"preserve\">" + content + "</div></body>"
        #call to convert xml to leiden
        transformed = HGVTransIdentifier.xml2nonxml(wrapped_content)
        #remove <T=.en and =T> that represents the <div> wrapping
        if (transformed)
          transformed.slice!(/^<T=.en/)
          transformed.slice!(/=T>$/)
        end
      else
        #wrap in <body>, <div>, and <p> tags so that the sugar grammer can transform 
        #assume neither <div> or <p> was provided
        wrapped_content = "<body xmlns:xml=\"http://www.w3.org/XML/1998/namespace\"><div xml:lang=\"en\" type=\"translation\" xml:space=\"preserve\"><p>" + content + "</p></div></body>"
        #call to convert xml to leiden
        transformed = HGVTransIdentifier.xml2nonxml(wrapped_content)
        #remove <T=.en<= and =>=T> that represents the <div> and <p> wrapping
        if (transformed)
          transformed.slice!(/^<T=.en<=/)
          transformed.slice!(/=>=T>$/)
        end
      end
    end
    return transformed
  end
  
  def self.get_language_translation_leiden(lang)
 	
    #wrap so that the sugar grammer can transform
    content = '<body xmlns:xml="http://www.w3.org/XML/1998/namespace"><div xml:lang="' + lang + '" type="translation" xml:space="preserve"><p></p></div></body>'
    #call to convert xml to leiden
    transformed = HGVTransIdentifier.xml2nonxml(content)
  
    return transformed
  end
  
  def self.translation_leiden_to_xml(content)
    if content.include?("<T=") #check if user input contains Leiden+ grammar for <div> tag
      #no need to wrap - already meets minimum for sugar grammar
      #call to convert leiden to xml
      wrapped_transformed = HGVTransIdentifier.nonxml2xml(content)
      # remove namespace assignment or REXML barfs
      wrapped_transformed.sub!(/ xmlns:xml="http:\/\/www.w3.org\/XML\/1998\/namespace"/,'')
      # pull out wrapped XML inside <body> tag
      transformed = REXML::XPath.match(REXML::Document.new(wrapped_transformed), '/body/[not(self::body)]')
    else
      if content.include?("<=") #check if user input contains Leiden+ grammar for <p> tag
        #wrap in <div> to meet minimum for sugar grammar
        wrapped_content = '<T=.en' + content + '=T>'
        #call to convert leiden to xml
        wrapped_transformed = HGVTransIdentifier.nonxml2xml(wrapped_content)
        # remove namespace assignment or REXML barfs
        wrapped_transformed.sub!(/ xmlns:xml="http:\/\/www.w3.org\/XML\/1998\/namespace"/,'')
        # pull out wrapped XML inside <div> tag
        transformed = REXML::XPath.match(REXML::Document.new(wrapped_transformed), '/body/div/[not(self::div)]')
      else
        #wrap in <div> and <p> tag to meet minimum for sugar grammar
        wrapped_content = '<T=.en <=' + content + '=>=T>'
        #call to convert leiden to xml
        wrapped_transformed = HGVTransIdentifier.nonxml2xml(wrapped_content)
        # remove namespace assignment or REXML barfs
        wrapped_transformed.sub!(/ xmlns:xml="http:\/\/www.w3.org\/XML\/1998\/namespace"/,'')
        # pull out wrapped XML inside <p> tag
        transformed = REXML::XPath.match(REXML::Document.new(wrapped_transformed), '/body/div/p/[not(self::p)]')
      end
    end
    return transformed
  end
  
end