class PublicationsController < ApplicationController
  ##layout 'site'
  before_filter :authorize
  before_filter :ownership_guard, :only => [:confirm_archive, :archive, :confirm_withdraw, :withdraw, :confirm_delete, :destroy, :submit]
  
  def new
  end
  
 
  def determine_creatable_identifiers
    @creatable_identifiers = @publication.creatable_identifiers
  end

  def advanced_create()
    
  end

  # POST /publications
  # POST /publications.xml
  def create
    @publication = Publication.new()
    @publication.owner = @current_user
    @publication.populate_identifiers_from_identifiers(
      params[:pn_id])
    
    @publication.creator = @current_user
    #@publication.creator_type = "User"
    #@publication.creator_id = @current_user
    
    if @publication.save
      @publication.branch_from_master
      
      # need to remove repeat against publication model
      e = Event.new
      e.category = "started editing"
      e.target = @publication
      e.owner = @current_user
      e.save!
      
      flash[:notice] = 'Publication was successfully created.'
      expire_publication_cache
      redirect_to edit_polymorphic_path([@publication, @publication.entry_identifier])
    else
      flash[:notice] = 'Error creating publication'
      redirect_to dashboard_url
    end
  end
  
  def create_from_identifier
    if params[:id].blank?
      flash[:error] = 'You must specify an identifier.'
      redirect_to dashboard_url
      return
    end
    
    identifier = params[:id]
    
    related_identifiers = NumbersRDF::NumbersHelper.identifier_to_identifiers(identifier)
    
    publication_from_identifier(identifier, related_identifiers)
  end

  def create_from_templates
    @publication = Publication.new_from_templates(@current_user)
    
    # need to remove repeat against publication model
    e = Event.new
    e.category = "created"
    e.target = @publication
    e.owner = @current_user
    e.save!
    
    flash[:notice] = 'Publication was successfully created.'
    #redirect_to edit_polymorphic_path([@publication, @publication.entry_identifier])
    expire_publication_cache
    redirect_to @publication
  end

  #list is in the form of pn id's separated by returns
  # such as
  #papyri.info/ddbdp/bgu;7;1504
  #papyri.info/ddbdp/bgu;7;1505
  #papyri.info/ddbdp/bgu;7;1506
  def create_from_list
    id_list = params[:pn_id_list].split(/\s+/) #(/\r\n?/)
    list_is_good = true
    
    #get rid of any blank lines, etc
    id_list = id_list.compact.reject { |s| s.strip.empty? }
    
    #check that the list is in the correct form
    #clean up the ids
    id_list.map! do |id|
      # FIXME: once biblio is loaded into numbers server, remove this unless clause
      unless id =~ /#{NumbersRDF::NAMESPACE_IDENTIFIER}\/#{BiblioIdentifier::IDENTIFIER_NAMESPACE}/
        id.chomp!('/');
        id = NumbersRDF::NumbersHelper.identifier_url_to_identifier(id)
        #check if there is a good response from the number server
        response =  NumbersRDF::NumbersHelper.identifier_to_numbers_server_response(id)
        
        #puts id + " returned " + response.code # + response.body
        if response.code != '200'
          
          #bad format most likely
          id = "Numbers Server Error, Check format--> " + id
          list_is_good = false
          
        elsif !response.body.index('rdf:Description')
          
          #item does not exist most likely
          #puts "text is bad"
          id = "Not Found--> " + id
          list_is_good = false
          
        end
      end
      id
    end
    
    if !list_is_good
      #recreate list
      error_str  = "Unable to create Publication.<br />"
      id_list.each do |id|
       error_str = error_str + id + "<br />"
      end
      flash[:error] = error_str
      redirect_to :action => 'advanced_create'
      return
    end
    
    
    #clean up any duplicated lines
    id_list = id_list.uniq
    
    publication_from_identifiers(id_list)
  end

  def submit

    #prevent resubmitting...most likely by impatient clicking on submit button
    if ! %w{editing new}.include?(@publication.status)
      flash[:error] =  'Publication has already been submitted. Did you click "Submit" multiple times?'
      redirect_to @publication
      return
    end
    
    #check if we are submitting to a community
    #community_id = params[:community_id]
    if params[:community] && params[:community][:id]
      community_id = params[:community][:id]
      community_id.strip
      if !community_id.empty? && community_id != "0" && !community_id.nil?
        @publication.community_id = community_id
        Rails.logger.info "Publication " + @publication.id.to_s + " " + @publication.title + " will be submitted to " + @publication.community.format_name
      else
        #force community id to nil for sosol
        @publication.community_id = nil;        
        Rails.logger.info "Publication " + @publication.id.to_s + " " + @publication.title + " will be submitted to SoSOL"
      end
      
    else
      #force community id to 0 for sosol
      @publication.community_id = nil;
    end
    
    
    #need to set id to 0
    #raise community_id
    
    #@comment = Comment.new( {:git_hash => @publication.recent_submit_sha, :publication_id => params[:id], :comment => params[:submit_comment], :reason => "submit", :user_id => @current_user.id } )
    #git hash is not yet known, but we need the comment for the publication.submit to add to the changeDesc
    @comment = Comment.new( {:publication_id => params[:id], :comment => params[:submit_comment], :reason => "submit", :user_id => @current_user.id } )
    @comment.save
    
    error_text, identifier_for_comment = @publication.submit
    if error_text == ""
      #update comment with git hash when successfully submitted
      @comment.git_hash = @publication.recent_submit_sha
      @comment.identifier_id = identifier_for_comment
      @comment.save
      expire_publication_cache
      expire_fragment(/board_publications_\d+/)
      flash[:notice] = 'Publication submitted.'
    else
      #cleanup comment that was inserted before submit completed that is no longer valid because of submit error
      cleanup_id = Comment.find(:last, :conditions => {:publication_id => params[:id], :reason => "submit", :user_id => @current_user.id } )
      Comment.destroy(cleanup_id)
      flash[:error] = error_text
    end
    redirect_to @publication
    # redirect_to edit_polymorphic_path([@publication, @publication.entry_identifier])
  end
  
  # GET /publications
  # GET /publications.xml
  def index
    @branches = @current_user.repository.branches
    @branches.delete("master")
    
    @publications = Publication.find_all_by_owner_id(@current_user.id)
    # just give branches that don't have corresponding publications
    @branches -= @publications.map{|p| p.branch}

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @publications }
    end
  end
  
  def become_finalizer
    # TODO make sure we don't steal it from someone who is working on it
    @publication = Publication.find(params[:id])
    @publication.remove_finalizer
    
    #note this can only be called on a board owned publication
    if @publication.owner_type != "Board"
      flash[:error] = "Can't change finalizer on non-board copy of publication."
      redirect_to show
    end
    @publication.send_to_finalizer(@current_user)
    #redirect_to (dashboard_url) #:controller => "publications", :action => "finalize_review" , :id => new_publication_id
    redirect_to :controller => 'user', :action => 'dashboard', :board_id => @publication.owner.id
  
  end
  
  def finalize_review
    
    @publication = Publication.find(params[:id])
    @identifier = nil#@publication.entry_identifier
    #if we are finalizing then find the board that this pub came from 
    # and find the identifers that the board controls
    if @publication.parent.owner_type == "Board"
      @publication.identifiers.each do |id|
        if @publication.parent.owner.controls_identifier?(id)
          @identifier = id
          #TODO change to array if board can control multiple identifiers
        end
      end      
    end
    @diff = @publication.diff_from_canon
    if @diff.blank?
      flash[:error] = "WARNING: Diff from canon is empty. Something may be wrong."
    end
    @is_editor_view = true
  end
  
 
  
  def finalize
    @publication = Publication.find(params[:id])

    #to prevent a community publication from being finalized if there is no end_user to get the final version
    if @publication.is_community_publication? && @publication.community.end_user.nil? 
      flash[:error] = "Error finalizing. No End User for the community."
      redirect_to @publication
      return
    end
    
    #find all modified identiers in the publication so we can set the votes into the xml
    @publication.identifiers.each do |id|
      #board controls this id and it has been modified
      if id.modified? && @publication.find_first_board.controls_identifier?(id) && (id.class.to_s != "BiblioIdentifier")
        id.update_revision_desc(params[:comment], @current_user);
        id.save
      end
    end
    
    
    #if it is a community pub, we don't commit to canon
    #instead we copy changes back to origin
    if @publication.is_community_publication?
      
      @publication.copy_back_to_user(params[:comment], @current_user)
  
    if false  #moved this to model...

      
=begin      
      Rails.logger.info "==========COMMUNITY PUBLICATION=========="
      Rails.logger.info "----Community is " + @publication.community.name
      Rails.logger.info "----Board is " + @publication.find_first_board.name
      
      Rails.logger.info "====creators publication begining finalize=="
      @publication.origin.log_info
=end            
        
      #determine where to get data to build the index, 
      # controlled paths are from the finalizer (this) publication
      # uncontrolled paths are from the origin publication
   
      controlled_paths =  Array.new(@publication.controlled_paths)
      #get the controlled blobs from the local branch (the finalizer's)
      #controlled_blobs are the files that the board controls and have changed
      controlled_blobs = controlled_paths.collect do |controlled_path|
        @publication.owner.repository.get_blob_from_branch(controlled_path, @publication.branch)
      end
      #combine controlled paths and blobs into a hash  
      controlled_paths_blobs = Hash[*((controlled_paths.zip(controlled_blobs)).flatten)]
      
      #determine existing uncontrolled paths & blobs
      #uncontrolled are taken from the origin, they have not been changed by board
      origin_identifier_paths = @publication.origin.identifiers.collect do |i|
        i.to_path
      end
      uncontrolled_paths = origin_identifier_paths - controlled_paths
      uncontrolled_blobs = uncontrolled_paths.collect do |ucp|
        @publication.origin.repository.get_blob_from_branch(ucp, @publication.origin.branch)
      end
      uncontrolled_paths_blobs = Hash[*((uncontrolled_paths.zip(uncontrolled_blobs)).flatten)]
        
     
=begin     
      Rails.logger.info "----Controlled paths for community publication are:" + controlled_paths.inspect      
      Rails.logger.info "--uncontrolled paths: "  + uncontrolled_paths.inspect
    
      Rails.logger.info "-----Uncontrolled Blobs are:"
      uncontrolled_blobs.each do |cb|
        Rails.logger.info "-" + cb.to_s
      end            
      Rails.logger.info "-----Controlled Blobs are:"
      controlled_blobs.each do |cb|
        Rails.logger.info "-" + cb.to_s
      end
=end

      #goal is to copy final blobs back to user's original publication (and preserve other blobs in original publication)
      origin_index = @publication.origin.owner.repository.repo.index
      origin_index.read_tree('master')
      
      Rails.logger.debug "=======orign INDEX before add========"
      Rails.logger.debug origin_index.inspect
      
      
      #add the controlled paths to the index
      controlled_paths_blobs.each_pair do |path, blob|
         origin_index.add(path, blob.data)
         Rails.logger.debug "--Adding controlled path blob: " + path + " " + blob.data
      end
      
      #need to add exiting tree to index, except for controlled blobs
      uncontrolled_paths_blobs.each_pair do |path, blob|
          origin_index.add(path, blob.data)
          Rails.logger.debug "--Adding uncontrolled path blob: " + path + " " + blob.data
      end
      

      Rails.logger.debug "=======orign INDEX after add========"
      Rails.logger.debug origin_index.inspect
      
      
      #Rails.logger.info 
      origin_index.commit(params[:comment],  @publication.origin.head, @current_user , nil, @publication.origin.branch)
      #Rails.logger.info origin_index.commit("comment",  @publication.origin.head, nil, nil, @publication.origin.branch)

      @publication.origin.save
      
=begin      
      Rails.logger.info "====creators publication after finalize=="
      @publication.origin.log_info
=end      
   
   end  #moved this to model...
   
      
    else #commit to canon
      begin
        canon_sha = @publication.commit_to_canon
        expire_publication_cache(@publication.creator.id)
        expire_fragment(/board_publications_\d+/)
      rescue Errno::EACCES => git_permissions_error
        flash[:error] = "Error finalizing. Error message was: #{git_permissions_error.message}. This is likely a filesystems permissions error on the canonical Git repository. Please contact your system administrator."
        redirect_to @publication
        return
      end    
    end


    #go ahead and store a comment on finalize even if the user makes no comment...so we have a record of the action  
    @comment = Comment.new()
  
    if params[:comment] && params[:comment] != ""  
      @comment.comment = params[:comment]
    else
      @comment.comment = "no comment"
    end
    @comment.user = @current_user
    @comment.reason = "finalizing"
    @comment.git_hash = canon_sha
    #associate comment with original identifier/publication
    @comment.identifier_id = params[:identifier_id]
    @comment.publication = @publication.origin
    
    @comment.save
    
    #create an event to show up on dashboard
    @event = Event.new()
    @event.owner = @current_user
    @event.target = @publication.parent #used parent so would match approve event
    @event.category = "committed"
    @event.save!
    
    #TODO need to submit to next board
    #need to set status of ids
    @publication.set_origin_and_local_identifier_status("committed")
    @publication.set_board_identifier_status("committed")
    
    #as it is set up the finalizer will have a parent that is a board whose status must be set
    #check that parent is board
    if @publication.parent && @publication.parent.owner_type == "Board"              
      @publication.parent.archive
      @publication.parent.owner.send_status_emails("committed", @publication)
    #else #the user is a super user
    end
    
    #send publication to the next board
    error_text, identifier_for_comment = @publication.origin.submit_to_next_board
    if error_text != ""
      flash[:error] = error_text
    end
    @publication.change_status('finalized')
    
    flash[:notice] = 'Publication finalized.'
    redirect_to @publication
  end
  
  # GET /publications/1
  # GET /publications/1.xml
  def show
    
    begin
      @publication = Publication.find(params[:id])
    rescue    
      flash[:error] = "Publication not found"
      redirect_to (dashboard_url)
      return
    end
    @is_editor_view = true 
    @all_comments, @xml_only_comments = @publication.get_all_comments(@publication.title.split("/").last)

    @show_submit = allow_submit?
    
    #only let creator delete
    @allow_delete = @current_user.id == @publication.creator.id 
    #only delete new or editing
    @allow_delete = @allow_delete && (@publication.status == "new" || @publication.status == "editing")
    @identifier = @publication.entry_identifier
    
    #todo - if any part has been approved, do we want them to be able to delete the publication or force it to an archve? this would only happen if a board returns their part after another board has approved their part
    
    #find other users who are editing the same thing
    @other_user_publications = Publication.other_users(@publication.title, @current_user.id)
    

    determine_creatable_identifiers()
    
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @publication }
    end
  end
  
  # GET /publications/1/edit
  def edit
    @publication = Publication.find(params[:id])
    
    redirect_to edit_polymorphic_path([@publication, @publication.entry_identifier])
  end
  
  def edit_text
    @publication = Publication.find(params[:id])
    @identifier = DDBIdentifier.find_by_publication_id(@publication.id)
    redirect_to edit_polymorphic_path([@publication, @identifier])
  end
  
  def edit_meta
    @publication = Publication.find(params[:id])
    @identifier = HGVMetaIdentifier.find_by_publication_id(@publication.id)
    redirect_to edit_polymorphic_path([@publication, @identifier])
  end
  
  def edit_trans  
    @publication = Publication.find(params[:id])    
    @identifier = HGVTransIdentifier.find_by_publication_id(@publication.id)
    redirect_to edit_polymorphic_path([@publication, @identifier])    
  end

  def edit_biblio
    @publication = Publication.find(params[:id])
    @identifier = BiblioIdentifier.find_by_publication_id(@publication.id)
    redirect_to edit_polymorphic_path([@publication, @identifier])
  end

 
  def edit_adjacent
  
    #if they are on show, then need to goto first or last identifers
    if params[:current_action_name] == "show"
      @publication = Publication.find(params[:id])
      if params[:direction] == 'prev'
        @identifier = @publication.identifiers.last
      else
        @identifier = @publication.identifiers.first
      end
      redirect_to edit_polymorphic_path([@publication, @identifier])
      return
    end
    
    @publication = Publication.find(params[:pub_id])

    if params[:direction] == 'prev'
      direction = -1
    else #assume next params[:direction] == 'next'
      direction = 1
    end

    @identifier = Identifier.find(params[:id_id])
    current_identifier_class = @identifier.class
    current_index = @publication.identifiers.index(@identifier)

    return_index = current_index + direction
    if (return_index < 0)
      redirect_to @publication
      return
      #or for loop over without overview
      #return_index = @publication.identifiers.length - 1
    elsif (return_index >= @publication.identifiers.length)
      redirect_to @publication
      return
      #or for loop over without overview
      #return_index = 0
    end

    @identifier = @publication.identifiers[return_index]
    if (@identifier.class != current_identifier_class)
      #if no longer the same class, we can't assume that the next class as the same edit methods
      redirect_to edit_polymorphic_path([@publication, @identifier])
    else
      #/publications/1/identifiers/1/action
      redirect_to :controller => params[:current_controller_name], :action => params[:current_action_name], :id => @identifier.id, :publication_id => params[:pub_id]
    end
  end



  def create_from_selector
    identifier_class = params[:IdentifierClass]
    collection = params["#{identifier_class}CollectionSelect".intern]
    volume = params[:volume_number]
    document = params[:document_number]
    
    if volume == 'Volume Number'
      volume = ''
    end
    
    if (document == 'Document Number') || document.blank?
      flash[:error] = 'Error creating publication: you must specify a document number'
      redirect_to dashboard_url
      return
    end
    
    if identifier_class == 'DDBIdentifier'
      document_path = [collection, volume, document].join(';')
    elsif identifier_class == 'HGVIdentifier'
      collection = collection.tr(' ', '_')
      if volume.blank?
        document_path = [collection, document].join('_')
      else
        document_path = [collection, volume, document].join('_')
      end
    end
    
    namespace = identifier_class.constantize::IDENTIFIER_NAMESPACE
    
    identifier = [NumbersRDF::NAMESPACE_IDENTIFIER, namespace, document_path].join('/')
    
    if identifier_class == 'HGVIdentifier'
      related_identifiers = NumbersRDF::NumbersHelper.collection_identifier_to_identifiers(identifier)
    else
      related_identifiers = NumbersRDF::NumbersHelper.identifier_to_identifiers(identifier)
    end
    
    publication_from_identifier(identifier, related_identifiers)
  end
  
  def vote
    #note that votes will go with the boards copy of the pub and identifiers
    #  vote history will also be recorded in the comment of the origin pub and identifier
    
    #fails - if not pub found ie race condition of voting on reject or graffiti
    begin
      @publication = Publication.find(params[:id])  
    rescue    
      flash[:warning] = "Publication not found - voting is over for this publications."
      redirect_to (dashboard_url)
      return
    end

    #fails - vote choice not given
    if params[:vote].blank? || params[:vote][:choice].blank?
      flash[:error] = "You must select a vote choice."
      
      redirect_to edit_polymorphic_path([@publication, params[:vote].blank? ? @publication.entry_identifier : Identifier.find(params[:vote][:identifier_id])])
      return
    end

    #fails - voting is over
    if @publication.status != "voting" 
      flash[:warning] = "Voting is over for this publication."
      redirect_to @publication
      return
    end
    
    Vote.transaction do
      #note that votes go to the publication's identifier
      @vote = Vote.new(params[:vote])
      @vote.user_id = @current_user.id
      
      vote_identifier = @vote.identifier.lock!
      @publication.lock!

      #fails - publication not in correct ownership
      if @publication.owner_type != "Board"
        #we have a problem since no one should be voting on a publication if it is not in theirs
        flash[:error] = "You do not have permission to vote on this publication which you do not own!"
        #kind a harsh but send em back to their own dashboard
        redirect_to dashboard_url
        return
      else
        @vote.board_id = @publication.owner_id
      end
    
      @comment = Comment.new()
      @comment.comment = @vote.choice + " - " + params[:comment][:comment]
      @comment.user = @current_user
      @comment.reason = "vote"
      #use most recent sha from identifier
      @comment.git_hash = vote_identifier.get_recent_commit_sha
      #associate comment with original identifier/publication
      @comment.identifier = vote_identifier.origin   
      @comment.publication = @vote.publication.origin

      #double check that they have not already voted
      #has_voted = vote_identifier.votes.find_by_user_id(@current_user.id)
      has_voted = @publication.user_has_voted?(@current_user.id)
      if !has_voted 
        @comment.save!
        @vote.save!
        # invalidate their cache since an action may have changed its status
        expire_publication_cache(@publication.creator.id)
        expire_fragment(/board_publications_\d+/)
      end
    end

    begin
      #see if publication still exists
      Publication.find(params[:id])
      redirect_to @publication
      return
    rescue
      #voting destroyed publication so go to the dashboard
      redirect_to dashboard_url
      return
    end
  end
  
  def confirm_archive
    @publication = Publication.find(params[:id])
  end
  
  def confirm_archive_all
    if @current_user.id.to_s != params[:id]
      if @current_user.developer || @current_user.admin
        flash.now[:warning] = "You are going to archive publications you do not own as either a developer or an admin."
      else
        flash[:error] = 'You are only allowed to archive your publications.'
        redirect_to dashboard_url
      end
    end
    @publications = Publication.find_all_by_owner_id(params[:id], :conditions => {:owner_type => 'User', :status => 'committed', :creator_id => params[:id], :parent_id => nil }, :order => "updated_at DESC")
    
  end
  
  def archive
    archive_pub(params[:id])
    expire_publication_cache
    redirect_to @publication    
  end
  
  # - loop thru all the committed publication ids and archive each one
  # - clear the cache
  # - go to the dashboard
  def archive_all
    params[:pub_ids].each do |id|
       archive_pub(id)
    end
    expire_publication_cache
    redirect_to dashboard_url 
  end
  
  def confirm_withdraw
   @publication = Publication.find(params[:id])
  end

  def withdraw
    @publication = Publication.find(params[:id])
    pub_name = @publication.title
    @publication.withdraw
    
    #send email to the user informing them of the withdraw
    #EmailerMailer.deliver_send_withdraw_note(@publication.creator.email, @publication.title )
    address = @publication.creator.email
    if address && address.strip != ""
      begin
        EmailerMailer.deliver_send_withdraw_note(address, @publication.title )                       
      rescue Exception => e
        Rails.logger.error("Error sending withdraw email: #{e.class.to_s}, #{e.to_s}")
      end
    end

    flash[:notice] = 'Publication ' + pub_name + ' was successfully withdrawn.'
    expire_publication_cache
    redirect_to dashboard_url
  end 
  
  def confirm_delete
    @publication = Publication.find(params[:id])
  end
  
  # DELETE 
  def destroy
    @publication = Publication.find(params[:id])
    pub_name = @publication.title
    @publication.destroy
    
    flash[:notice] = 'Publication ' + pub_name + ' was successfully deleted.'
    expire_publication_cache
    respond_to do |format|
      format.html { redirect_to dashboard_url }
      
    end
  end
  
  
  def master_list
    if @current_user.developer
      @publications = Publication.find(:all)
    else
      redirect_to dashboard_url
    end
  end
  
  protected
    def find_publication
      @publication ||= Publication.find(params[:id])
    end

    def ownership_guard
      find_publication
      if !@publication.mutable_by?(@current_user)
        flash[:error] = 'Operation not permitted.'
        redirect_to dashboard_url
      end
    end
  
    def allow_submit?
      #check if publication has been changed by user
      allow = @publication.modified?
      
      #only let creator submit
      allow = allow && @publication.creator_id == @current_user.id 
      
      #only let user submit, don't let a board member submit
      allow = allow && @publication.owner_type == "User"
      
      #dont let user submit if already submitted, or committed etc..
      allow = allow && ((@publication.status == "editing") || (@publication.status == "new"))
      
      return allow
      
      #below bypassed until we have return mechanism in place
      
      #check if any part of the publication is still being edited (ie not already submitted)
      if allow #something has been modified so lets see if they can submit it
        allow = false #dont let them submit unless something is in edit status
        @publication.identifiers.each  do |identifier|
          if identifier.nil? || identifier.status == "editing" 
            allow = true
          end        
        end
      end
     allow
    end
 

    def publication_from_identifiers(identifiers)
      new_title = 'Batch_' + Time.now.strftime("%d%b%Y_%H%M")
      publication_from_identifier("unused_place_holder", identifiers, new_title)


=begin
      #do we need to check for conflicts with the batches?
      #might be able to modify publication_from_identifier
      #where to get title? make them up based on time for now
      new_title = 'Batch_' + Time.now.strftime("%d%b%Y_%H%M") #12Jan2011_2359
      puts new_title
        @publication = Publication.new()
        @publication.owner = @current_user
        @publication.creator = @current_user

        @publication.populate_identifiers_from_identifiers(
          identifiers, new_title)

        if @publication.save!
          @publication.branch_from_master

          # need to remove repeat against publication model
          e = Event.new
          e.category = "started editing"
          e.target = @publication
          e.owner = @current_user
          e.save!

          flash[:notice] = 'Publication was successfully created.'
          expire_publication_cache
          redirect_to edit_polymorphic_path([@publication, @publication.entry_identifier])
        else
          flash[:notice] = 'Error creating publication'
          redirect_to dashboard_url
        end
=end
    end

    def publication_from_identifier(identifier, related_identifiers = nil, optional_title = nil)
      Rails.logger.info("Identifier: #{identifier}")
      Rails.logger.info("Related identifiers: #{related_identifiers.inspect}")

      conflicting_identifiers = []

      if related_identifiers.nil?
        flash[:error] = 'Error creating publication: publication not found'
        redirect_to dashboard_url
        return
      end

      related_identifiers.each do |relid|
        possible_conflicts = Identifier.find_all_by_name(relid, :include => :publication)
        actual_conflicts = possible_conflicts.select {|pc| ((pc.publication) && (pc.publication.owner == @current_user) && !(%w{archived finalized}.include?(pc.publication.status)))}
        conflicting_identifiers += actual_conflicts
      end

      if related_identifiers.length == 0
        flash[:error] = 'Error creating publication: publication not found'
        redirect_to dashboard_url
        return
      elsif conflicting_identifiers.length > 0
        Rails.logger.info("Conflicting identifiers: #{conflicting_identifiers.inspect}")
        conflicting_publication = conflicting_identifiers.first.publication
        conflicting_publications = conflicting_identifiers.collect {|ci| ci.publication}.uniq

        if conflicting_publications.length > 1
          flash[:error] = 'Error creating publication: multiple conflicting publications'
          flash[:error] += '<ul>'
          conflicting_publications.each do |conf_pub|
            flash[:error] += "<li><a href='#{url_for(conf_pub)}'>#{conf_pub.title}</a></li>"
          end
          flash[:error] += '</ul>'

          redirect_to dashboard_url
          return
        end

        if (conflicting_publication.status == "committed")
          # TODO: should set "archived" and take approp action here instead
          #conflicting_publication.destroy
          expire_publication_cache
          conflicting_publication.archive
        else
          flash[:error] = "Error creating publication: publication already exists. Please delete the <a href='#{url_for(conflicting_publication)}'>conflicting publication</a> if you have not submitted it and would like to start from scratch."
          redirect_to dashboard_url
          return
        end
      end
      # else
        @publication = Publication.new()
        @publication.owner = @current_user
        @publication.creator = @current_user
        @publication.populate_identifiers_from_identifiers(
          related_identifiers, optional_title)

        if @publication.save!
          @publication.branch_from_master

          # need to remove repeat against publication model
          e = Event.new
          e.category = "started editing"
          e.target = @publication
          e.owner = @current_user
          e.save!

          flash[:notice] = 'Publication was successfully created.'
          expire_publication_cache
          #redirect_to edit_polymorphic_path([@publication, @publication.entry_identifier])
          redirect_to @publication
        else
          flash[:notice] = 'Error creating publication'
          redirect_to dashboard_url
        end
      # end
    end
  
    def expire_publication_cache(user_id = @current_user.id)
      expire_fragment(:controller => 'user', :action => 'dashboard', :part => "your_publications_#{user_id}")
    end
    
    def archive_pub(pub_id)
      @publication = Publication.find(pub_id)
      @publication.archive
    end
end
