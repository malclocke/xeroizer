module Xeroizer
  module Record
    module XmlHelper
      
      def self.included(base)
        base.extend(ClassMethods)
        base.send :include, InstanceMethods
      end
      
      module ClassMethods
        
        # Build a record instance from the XML node.
        def build_from_node(node, parent)
          record = new(parent)
          node.elements.each do | element |
            field = self.fields[element.name.to_s.underscore.to_sym]
            if field
              value = case field[:type]
                when :guid        then element.text
                when :string      then element.text
                when :boolean     then (element.text == 'true')
                when :integer     then element.text.to_i
                when :decimal     then BigDecimal.new(element.text)
                when :date        then Date.parse(element.text)
                when :datetime    then Time.parse(element.text)
                when :belongs_to  
                  model_name = field[:model_name] ? field[:model_name].to_sym : element.name.to_sym
                  Xeroizer::Record.const_get(model_name).build_from_node(element, parent)
                  
                when :has_many
                  if element.element_children.size > 0
                    sub_field_name = field[:model_name] ? field[:model_name].to_sym : element.children.first.name.to_sym
                    sub_parent = record.new_model_class(sub_field_name)
                    element.children.inject([]) do | list, element |
                      list << Xeroizer::Record.const_get(sub_field_name).build_from_node(element, sub_parent)
                    end
                  end

              end
              if field[:calculated]
                record.attributes[field[:internal_name]] = value
              else
                record.send("#{field[:internal_name]}=", value)
              end
            end
          end
          
          record
        end
        
      end
      
      module InstanceMethods
        
        public
        
          # Turn a record into its XML representation.
          def to_xml(b = Builder::XmlMarkup.new(:indent => 2))
            b.tag!(parent.model_name) { 
              attributes.each do | key, value |
                unless value.nil?
                  field = self.class.fields[key]
                  xml_value_from_field(b, field, value)
                end
              end
            }
          end
          
        protected
        
          # Format a attribute for use in the XML passed to Xero.
          def xml_value_from_field(b, field, value)
            case field[:type]
              when :guid        then b.tag!(field[:api_name], value)
              when :string      then b.tag!(field[:api_name], value)
              when :boolean     then b.tag!(field[:api_name], value ? 'true' : 'false')
              when :integer     then b.tag!(field[:api_name], value.to_i)
              when :decimal   
                real_value = case value
                  when BigDecimal   then value.to_s
                  when String       then BigDecimal.new(value).to_s
                  else              value
                end
                b.tag!(field[:api_name], real_value)

              when :date
                real_value = case value
                  when Date         then value.strftime("%Y-%m-%d")
                  when Time         then value.utc.strftime("%Y-%m-%d")
                end
                b.tag!(field[:api_name], real_value)
                
              when :datetime    then b.tag!(field[:api_name], value.utc.strftime("%Y-%m-%dT%H:%M:%S"))
              when :belongs_to  
                value.to_xml(b)
                nil

              when :has_many    
                if value.size > 0
                  b.tag!(value.first.parent.model_name.pluralize) {
                    value.each { | record | record.to_xml(b) }
                  }
                  nil
                end

            end
          end
        
      end
      
    end
  end
end
