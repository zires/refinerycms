require 'mime/types'

module Admin
  class ResourcesController < Admin::BaseController

    crudify :resource, :order => "updated_at DESC"
    before_filter :init_dialog

    def new
      @resource = Resource.new if @resource.nil?

      @url_override = admin_resources_url(:dialog => from_dialog?)
    end

    def create
      @resources = []
      unless params[:resource].present? and params[:resource][:file].is_a?(Array)
        # Set the MIME type, since Flash doesn't do it properly. As suggested here:
        # http://www.glrzad.com/ruby-on-rails/using-uploadify-with-rails-3-part-2-controller-example/
        params[:resource][:file].content_type = MIME::Types.type_for(params[:resource][:file].original_filename).to_s
        @resources << (@resource = Resource.create(params[:resource]))
      else
        params[:resource][:file].each do |resource|
          # Ditto
          resource.content_type = MIME::Types.type_for(resource.original_filename).to_s
          @resources << (@resource = Resource.create(:file => resource))
        end
      end

      unless params[:insert]
        if @resources.all?{|r| r.valid?}
          flash.notice = t('refinery.crudify.created', :what => "'#{@resources.collect{|r| r.title}.join("', '")}'")
          unless from_dialog?
            redirect_to :action => 'index'
          else
            render :text => "<script>parent.window.location = '#{admin_resources_url}';</script>"
          end
        else
          self.new # important for dialogs
          render :action => 'new'
        end
      else
        if @resources.all?{|r| r.valid?}
          @resource_id = @resource.id if @resource.persisted?
          @resource = nil
        end
        self.insert
      end
    end

    def index
      search_all_resources if searching?
      paginate_all_resources

      render :partial => 'resources' if request.xhr?
    end

    def insert
      self.new if @resource.nil?

      @url_override = admin_resources_url(:dialog => from_dialog?, :insert => true)

      if params[:conditions].present?
        extra_condition = params[:conditions].split(',')

        extra_condition[1] = true if extra_condition[1] == "true"
        extra_condition[1] = false if extra_condition[1] == "false"
        extra_condition[1] = nil if extra_condition[1] == "nil"
        paginate_resources({extra_condition[0].to_sym => extra_condition[1]})
      else
        paginate_resources
      end
      render :action => "insert"
    end

    def update
      if @resource.update_attributes(params[:resource])
        (request.xhr? ? flash.now : flash).notice = t(
          'refinery.crudify.updated',
          :what => "'\#{@resource.title}'"
        )

        # Redirect will be handled in the script
        if params[:uploadify]
          flash.notice = 'HEY!'
          flash.keep
          render :text => 'Ok'
          return
        end

        unless from_dialog?
          unless params[:continue_editing] =~ /true|on|1/
            redirect_back_or_default(admin_resource_url)
          else
            unless request.xhr?
              redirect_to :back
            else
              render :partial => "/shared/message"
            end
          end
        else
          render :text => "<script>parent.window.location = '\#{admin_resource_url}';</script>"
        end
      else
        unless request.xhr?
          render :action => 'edit'
        else
          render :partial => "/shared/admin/error_messages",
                 :locals => {
                   :object => @resource,
                   :include_object_name => true
                 }
        end
      end
    end

  protected

    def init_dialog
      @app_dialog = params[:app_dialog].present?
      @field = params[:field]
      @update_resource = params[:update_resource]
      @update_text = params[:update_text]
      @thumbnail = params[:thumbnail]
      @callback = params[:callback]
      @conditions = params[:conditions]
      @current_link = params[:current_link]
    end

    def restrict_controller
      super unless action_name == 'insert'
    end

    def paginate_resources(conditions={})
      @resources = Resource.paginate   :page => (@paginate_page_number ||= params[:page]),
                                       :conditions => conditions,
                                       :order => 'created_at DESC',
                                       :per_page => Resource.per_page(from_dialog?)
    end

  end
end