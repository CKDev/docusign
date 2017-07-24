module Docusign
  class Template < ::ApplicationRecord

    mount_uploaders :documents, ::Docusign::DocumentUploader

    serialize :documents, JSON

    has_many :signers, as: :signable

    has_many :envelopes, autosave: true

    belongs_to :templatable, polymorphic: true, optional: true

    before_validation :validate_signers

    before_validation :create_template, on: :create

    before_validation :update_template, on: :update

    after_save :reset_data

    validates_presence_of :email_subject

    validates_presence_of :name

    def add_document(path)
      self.documents ||= []
      self.documents += [File.open(path)]
    end

    def add_signer(**args, &block)
      args = templatable.try(:to_signer) if args.empty? && templatable.present?
      signer = self.signers.build(args)
      signer.routing_order = next_route_order
      signer.instance_exec(&block) if block_given?
      signer
    end

    private

      # Get the last routing order from the current recipients, and increase by 1 to get the next order
      def next_route_order
        signers.map(&:routing_order).compact.sort.last.to_i + 1
      end

      def misc_data
        @misc_data ||= {}
      end

      def create_template
        response = Docusign.client.post('templates', payload: create_payload)

        if response.error?
          self.errors.add :base, response.message
        else
          self.template_id = response.template_id
        end
      end

      def update_template
        if changed? || !misc_data.blank?
          response = Docusign.client.put("templates/#{template_id}", payload: update_payload)

          if response.error?
            self.errors.add :base, response.message
          end
        end
      end

      def create_payload
        {
          email_subject: email_subject,
          email_blurb: email_blurb,
          documents: envelope_documents,
          envelope_template_definition: {
            description: description,
            name: name
          },
          recipients: {
            signers: envelope_signers
          }
        }.deep_merge(misc_data)
      end

      def update_payload
        {
          email_subject: email_subject,
          email_blurb: email_blurb,
          envelope_template_definition: {
            description: description,
            name: name
          }
        }.deep_merge(misc_data)
      end

      def envelope_documents
        idx = 0
        documents.map do |document|
          {
            documentBase64: Base64.encode64(document.read),
            documentId: idx += 1,
            fileExtension: document.file.extension,
            name: document.file.filename
          }
        end
      end

      # Get the hash data of all signers
      def envelope_signers
        signers.map(&:to_docusign)
      end

      # Ensure each signer has a recipient id before creating
      def validate_signers
        signers.map(&:valid?)
      end

      def reset_data
        @misc_data = {}
      end

      def method_missing(name, *args, &block)
        if name.to_s =~ /^(\w*)=$/
          misc_data[name.to_s.gsub(/=$/, '').to_sym] = args.first
        else
          super
        end
      end

  end
end