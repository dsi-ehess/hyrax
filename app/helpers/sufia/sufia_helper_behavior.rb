module Sufia
  module SufiaHelperBehavior
    include Sufia::CitationsBehavior

    def application_name
      t('sufia.product_name', default: super)
    end

    def institution_name
      t('sufia.institution_name')
    end

    def institution_name_full
      t('sufia.institution_name_full', default: institution_name)
    end

    def orcid_label(style_class = '')
      "#{image_tag 'orcid.png', alt: t('sufia.user_profile.orcid.alt'), class: style_class} #{t('sufia.user_profile.orcid.label')}".html_safe
    end

    def zotero_label(opts = {})
      html_class = opts[:html_class] || ''
      "#{image_tag 'zotero.png', alt: t('sufia.user_profile.zotero.alt'), class: html_class} #{t('sufia.user_profile.zotero.label')}".html_safe
    end

    def zotero_profile_url(zotero_user_id)
      "https://www.zotero.org/users/#{zotero_user_id}"
    end

    # Only Chrome supports this
    def browser_supports_directory_upload?
      user_agent.include? 'Chrome'
    end

    # @param [Hash] options a list of options that blacklight passes from helper_method
    #                       invocation.
    def human_readable_date(options)
      Date.parse(options[:value]).to_formatted_s(:standard)
    end

    def error_messages_for(object)
      if object.try(:errors) && object.errors.full_messages.any?
        content_tag(:div, class: 'alert alert-block alert-error validation-errors') do
          content_tag(:h4, I18n.t('sufia.errors.header', model: object.class.model_name.human.downcase), class: 'alert-heading') +
            content_tag(:ul) do
              object.errors.full_messages.map do |message|
                content_tag(:li, message)
              end.join('').html_safe
            end
        end
      else
        '' # return empty string
      end
    end

    def show_transfer_request_title(req)
      if req.deleted_work? || req.canceled?
        req.to_s
      else
        link_to(req.to_s, curation_concerns_generic_work_path(req.work_id))
      end
    end

    def has_collection_search_parameters?
      !params[:cq].blank?
    end

    def number_of_deposits(user)
      ActiveFedora::Base.where(DepositSearchBuilder.depositor_field => user.user_key).count
    end

    def link_to_facet(field, field_string)
      path = search_action_path(search_state.add_facet_params_and_redirect(field_string, field))
      link_to(field, path)
    end

    # @param values [Array] The values to display
    # @param solr_field [String] The name of the solr field to link to without its suffix (:facetable)
    # @param empty_message [String] ('No value entered') The message to display if no values are passed in.
    # @param separator [String] (', ') The value to join with.
    def link_to_facet_list(values, solr_field, empty_message = "No value entered", separator = ", ")
      return empty_message if values.blank?
      facet_field = Solrizer.solr_name(solr_field, :facetable)
      safe_join(values.map { |item| link_to_facet(item, facet_field) }, separator)
    end

    def link_to_field(name, value, label = nil, facet_hash = {})
      label ||= value
      params = { search_field: 'advanced', name => "\"#{value}\"" }
      state = search_state_with_facets(params, facet_hash)
      link_to(label, main_app.search_catalog_path(state))
    end

    # @param [String,Hash] text either the string to escape or a hash containing the
    #                           string to escape under the :value key.
    def iconify_auto_link(text, showLink = true)
      text = presenter(text[:document]).render_values(text[:value], text[:config]) if text.is_a? Hash
      # this block is only executed when a link is inserted;
      # if we pass text containing no links, it just returns text.
      auto_link(html_escape(text)) do |value|
        "<span class='glyphicon glyphicon-new-window'></span>#{('&nbsp;' + value) if showLink}"
      end
    end

    # @param [String,User,Hash] args if a hash, the user_key must be under :value
    def link_to_profile(args)
      user_or_key = args.is_a?(Hash) ? args[:value].first : args
      user = case user_or_key
             when User
               user_or_key
             when String
               ::User.find_by_user_key(user_or_key)
             end
      return user_or_key if user.nil?

      text = if user.respond_to? :name
               user.name
             else
               user_or_key
             end

      link_to text, Sufia::Engine.routes.url_helpers.profile_path(user)
    end

    # @param [Hash] options hash from blacklight passes from helper_method
    #                       invocation. Maps rights URIs to links with labels.
    def rights_statement_links(options = {})
      options[:value].map { |right| link_to RightsService.label(right), right }.to_sentence.html_safe
    end

    def link_to_telephone(user = nil)
      @user ||= user
      link_to @user.telephone, "wtai://wp/mc;#{@user.telephone}" if @user.telephone
    end

    # Only display the current search parameters if the user is not in the dashboard.
    # If they are in the dashboard, then the search defaults to the user's works and not
    # all of Sufia.
    def current_search_parameters
      return if on_the_dashboard?
      params[:q]
    end

    # Depending on which page we're landed on, we'll need to set the appropriate action url for
    # our search form.
    def search_form_action
      if on_the_dashboard?
        search_action_for_dashboard
      else
        main_app.search_catalog_path
      end
    end

    def render_visibility_link(document)
      # Anchor must match with a tab in
      # https://github.com/projecthydra/sufia/blob/master/app/views/curation_concerns/base/_guts4form.html.erb#L2
      link_to render_visibility_label(document),
              edit_polymorphic_path([main_app, document], anchor: "share"),
              id: "permission_" + document.id, class: "visibility-link"
    end

    def render_visibility_label(document)
      if document.registered?
        content_tag :span, institution_name, class: "label label-info", title: institution_name
      elsif document.public?
        content_tag :span, t('.visibility.open'), class: "label label-success", title: t('sufia.visibility.open_title_attr')
      else
        content_tag :span, t('sufia.visibility.private'), class: "label label-danger", title: t('sufia.visibility.private_title_attr')
      end
    end

    def user_display_name_and_key(user_key)
      user = ::User.find_by_user_key(user_key)
      return user_key if user.nil?

      user.respond_to?(:name) ? "#{user.name} (#{user_key})" : user_key
    end

    def collection_thumbnail(_document, _image_options = {}, _url_options = {})
      content_tag(:span, "", class: ["fa", "fa-cubes", "collection-icon-search"])
    end

    private

      def user_agent
        request.user_agent || ''
      end

      def search_action_for_dashboard
        case params[:controller]
        when "my/works"
          sufia.dashboard_works_path
        when "my/collections"
          sufia.dashboard_collections_path
        when "my/shares"
          sufia.dashboard_shares_path
        when "my/highlights"
          sufia.dashboard_highlights_path
        else
          sufia.dashboard_works_path
        end
      end

      def search_state_with_facets(params, facet = {})
        state = Blacklight::SearchState.new(params, CatalogController.blacklight_config)
        return state.params if facet.none?
        state.add_facet_params(Solrizer.solr_name(facet.keys.first, :facetable),
                               facet.values.first)
      end
  end
end
