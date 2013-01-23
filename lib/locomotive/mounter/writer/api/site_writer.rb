module Locomotive
  module Mounter
    module Writer
      module Api

        class SiteWriter < Base

          attr_accessor :remote_site

          # Check if the site has to be created before.
          def prepare
            super

            self.fetch_site

            # if self.fetch_site.nil?
            #   Mounter.logger.warn 'The site does not exist. Trying to create it.'

            #   unless self.has_admin_rights?
            #     raise Mounter::WriterException.new('Your account does not own admin rights.')
            #   end
            # else
            #   self.check_locales
            # end
          end

          # Create the site if it does not exist
          def write
            if self.site.persisted?
              self.check_locales! unless self.force? # requirements

              self.update_site
            else
              self.create_site
            end


            # unless self.site.persisted?
            #   # create it in the default locale
            #   Mounter.with_locale(self.default_locale) do
            #     self.output_locale

            #     self.output_resource_op self.site

            #     if (site = self.post(:sites, self.site.to_hash(false), Mounter.locale)).nil?
            #       raise Mounter::WriterException.new('Sorry, we are unable to create the site.')
            #     else
            #       self.site._id = site['id']

            #       self.output_resource_op_status self.site
            #     end
            #   end

            #   # update it in other locales
            #   self.site.translated_in.each do |locale|
            #     next if locale.to_s == self.default_locale.to_s
            #     Mounter.with_locale(locale) do
            #       self.output_locale

            #       self.output_resource_op self.site

            #       self.put(:sites, self.site._id, self.site.to_hash(false), Mounter.locale)

            #       self.output_resource_op_status self.site
            #     end
            #   end
            # else
            #   self.output_resource_op self.site
            #   self.output_resource_op_status self.site, :skipped
            # end
          end

          protected

          # Create the current site in all the locales
          #
          def create_site
            # create it in the default locale
            Mounter.with_locale(self.default_locale) do
              self.output_locale

              self.output_resource_op self.site

              if (site = self.post(:sites, self.site.to_hash(false), Mounter.locale)).nil?
                raise Mounter::WriterException.new('Sorry, we are unable to create the site.')
              else
                self.site._id = site['id']
                self.output_resource_op_status self.site
              end
            end

            # update it in other locales
            self.update_site(true)
          end

          # Update the current site in all the locales
          #
          # @param [ Boolean ] exclude_current_locale Update the site for all the locales other than the default one.
          #
          def update_site(exclude_current_locale = false)
            self.each_locale do |locale|
              next if exclude_current_locale && locale.to_s == self.default_locale.to_s

              self.output_locale

              begin
                self.output_resource_op self.site

                self.put(:sites, self.site._id, self.site.to_hash(false), locale)

                self.output_resource_op_status self.site
              rescue Exception => e
                self.output_resource_op_status self.site, :error, e.message
              end
            end
          end

          def safe_attributes
            %w(id locales)
          end

          def fetch_site
            self.get(:current_site).tap do |_site|
              if _site
                self.remote_site  = _site
                self.site._id     = _site['id']
              end
            end
          end

          # To push all the other resources, the big requirement is to
          # have the same locales between the local site and the remote one.
          #
          def check_locales!
            default_locale  = self.mounting_point.default_locale.to_s
            locales         = self.site.locales.map(&:to_s)
            remote_locales  = self.remote_site['locales']
            message         = nil

            unless locales.all? { |l| remote_locales.include?(l) }
              message = "Your site locales (#{locales.join(', ')}) do not match exactly the ones of your target (#{remote_locales.join(', ')})"
            end

            if default_locale != remote_locales.first
              message = "Your default site locale (#{default_locale.inspect}) is not the same as the one of your target (#{remote_locales.first.inspect})"
            end

            if message
              self.output_resource_op self.site
              self.output_resource_op_status self.site, :error, message
              raise Mounter::WriterException.new('Use the force option in order to force your locale settings.')
            end
          end

          def has_admin_rights?
            self.get(:my_account, nil, true)['admin']
          end

        end

      end
    end
  end
end