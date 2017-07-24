module Docusign
  class Signer < ::ApplicationRecord

    belongs_to :signable, polymorphic: true, required: false

    serialize :tabs, JSON

    validates_presence_of :name, :email, :role_name, :recipient_id

    before_validation :set_recipient_id, only: :create

    Docusign.config.tabs.each do |type|
      define_method "#{type}_at" do |text=nil, x=0, y=0, **params|
        self.tabs ||= {}
        self.tabs["#{type}_tabs".to_sym] ||= []
        self.tabs["#{type}_tabs".to_sym] << {
          anchor_string: text,
          anchor_x_offset: x,
          anchor_y_offset: y
        }.reject { |_,v| v.nil? }.merge(params)
      end
    end

    def to_docusign
      {
        embedded: embedded?,
        name: name,
        email: email,
        client_user_id: email,
        role_name: role_name,
        recipient_id: recipient_id,
        routing_order: routing_order,
        tabs: tabs || {}
      }.deep_merge(misc_data)
    end

    alias_method :sign_at, :sign_here_at

    alias_method :signed_at, :date_signed_at

    alias_method :fullname_at, :full_name_at

    alias_method :radio_at, :radio_group_at

    alias_method :initial_at, :initial_here_at

    private

      def misc_data
        @misc_data ||= {}
      end

      def set_recipient_id
        self.recipient_id = Digest::MD5.hexdigest([name, email, role_name].join)
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
