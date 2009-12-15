require 'net/http'
require 'jruby_xml'

module NumbersRDF
  NUMBERS_SERVER_DOMAIN = 'papyri.info'
  NUMBERS_SERVER_PORT = 80
  NUMBERS_SERVER_BASE_PATH = '/numbers'
  # OAI identifiers should be in the form scheme ":" namespace-identifier ":" local-identifier
  OAI_SCHEME = 'oai'
  OAI_NAMESPACE_IDENTIFIER = 'papyri.info'
  OAI_IDENTIFIER_PREFIX = "#{OAI_SCHEME}:#{OAI_NAMESPACE_IDENTIFIER}"
  PREFIX = "#{OAI_IDENTIFIER_PREFIX}:identifiers"
  
  module NumbersHelper
    class << self
      def identifier_to_local_identifier(identifier)
        identifier.sub(/^#{OAI_IDENTIFIER_PREFIX}:/, '')
      end
    
      def identifier_to_components(identifier)
        identifier.split(':')
      end

      def identifier_to_path(identifier)
        local_identifier = identifier_to_local_identifier(identifier)
        url_paths = [NUMBERS_SERVER_BASE_PATH] + 
                    identifier_to_components(local_identifier)
        return url_paths.join('/')
      end

      def identifier_to_url(identifier)
        return 'http://' + NUMBERS_SERVER_DOMAIN + ':' + 
                NUMBERS_SERVER_PORT + identifier_to_path(identifier)
      end
    
      def identifier_to_numbers_server_response(identifier)
        path = identifier_to_path(identifier)
        response = Net::HTTP.get_response(NUMBERS_SERVER_DOMAIN, path,
                                          NUMBERS_SERVER_PORT)
      end
    
      def identifier_to_identifiers(identifier)
        response = identifier_to_numbers_server_response(identifier)

        if response.code != '200'
          return nil
        else
          return process_numbers_server_response_body(response.body)
        end
      end
    
      def identifiers_to_hash(identifiers)
        identifiers_hash = Hash.new
        identifiers.each do |identifier|
          local_identifier = identifier_to_local_identifier(identifier)
          components = identifier_to_components(local_identifier)
          key = components[1]
          identifiers_hash[key] = 
            Array.new() unless identifiers_hash.has_key?(key)
          identifiers_hash[key] << identifier
        end
        return identifiers_hash
      end
    
      def process_numbers_server_response_body(rdf_xml)
        identifiers = []
        ore_describes_path = "/rdf:RDF/rdf:Description/*/rdf:Description/ore:describes"
        JRubyXML.apply_xpath(rdf_xml, ore_describes_path, true).each do |ore_describes|
          identifiers << ore_describes[:attributes]['rdf:resource']
        end
        
        return identifiers
      end
    end
  end
end