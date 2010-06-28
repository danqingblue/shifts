class CalendarFeedsController < ApplicationController
    skip_before_filter filter_chain, :except => [:index]
    
  def index
    shift_source = Struct.new( :type, :name, :token )
    @user=shift_source.new(current_user.class.name, current_user.name, generate_token(current_user, "Shift"))
    @shift_sources = [@user]
    current_user.departments.each do |department|
      @shift_sources << shift_source.new(department.class.name, department.name, generate_token(department, "Shift"))
    end  
    current_user.departments.each do |department|
      department.loc_groups.each do |loc_group|
        if current_user.can_view?(loc_group)
          @shift_sources << shift_source.new(loc_group.class.name, loc_group.name, generate_token(loc_group, "Shift"))
          loc_group.locations.each do |location|
            @shift_sources << shift_source.new(location.class.name, location.short_name, generate_token(location, "Shift"))
          end
        end
      end
     end
     @user=shift_source.new(current_user.class.name, current_user.name, generate_token(current_user, "SubRequest"))
     @sub_sources = [@user]
      current_user.departments.each do |department|
         @sub_sources << shift_source.new(department.class.name, department.name, generate_token(department, "SubRequest"))
       end  
       current_user.departments.each do |department|
         department.loc_groups.each do |loc_group|
           if current_user.can_view?(loc_group)
             @sub_sources << shift_source.new(loc_group.class.name, loc_group.name, generate_token(loc_group, "SubRequest"))
             loc_group.locations.each do |location|
               @sub_sources << shift_source.new(location.class.name, location.short_name, generate_token(location, "SubRequest"))
             end
           end
         end
       end
    end

  def reset
    current_user.calendar_feed_hash = nil
    current_user.save!
    flash[:notice] = 'All calendars reset.  NOTE: Your old feeds are now inactive'
    redirect_to :action => "index"
  end
  
  def grab
    begin
      @token_array = resolve_token(params[:token], params[:user_id])
      @user = User.find(params[:user_id])
    rescue Exception => e
      redirect_to :action => "index"
      flash[:error] = 'Could not load calendar feed.  This feed may be invalid, inactive, or disabled.'  
      return
    end 
    @shifts = []
    @source = @token_array[0]  
    @type = @token_array[1]
    if @type == "SubRequest"
       @shifts = @user.available_sub_requests(@source)      
    elsif @type == "Shift"
       case
        when @source.class.name == "Department" && @user.departments.include?(@source) && @user.is_active?(@source)
            @shifts = Shift.in_locations(@source.loc_groups.select {|lg| @user.can_view?(lg)}.collect(&:locations).flatten).after_date(Time.now.utc - 3.weeks).not_for_user(@user).flatten
        when @source.class.name == "LocGroup" && @user.can_view?(@source)
            @shifts = Shift.in_locations(@source.locations).after_date(Time.now.utc - 3.weeks).not_for_user(@user).flatten
        when @source.class.name == "Location" && @user.can_view?(@source.loc_group)
            @shifts = Shift.find(:all, :conditions => ["location_id = ? AND end >= ?", @source.id, Time.now.utc - 3.weeks]).not_for_user(@user)
        when @source.class.name == "User"
           @shifts = Shift.in_departments(@source.active_departments).for_user(@source).after_date(Time.now.utc - 3.weeks).flatten
      end
    end
    render :text => generate_ical
  end
  
  private
  
  def generate_token(source, type)
    if !current_user.calendar_feed_hash
      current_user.calendar_feed_hash = SecureRandom.hex(32)  #must be 32 characters
      current_user.save!
    end
      require 'openssl'
      require 'digest/sha2'
      cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      cipher.encrypt
      cipher.key = AppConfig.first.calendar_feed_hash      
      cipher.iv = current_user.calendar_feed_hash
      @token = cipher.update(source.class.name.to_s + ',' +  source.id.to_s + ',' + type)    #creates cipher from string
      @token << cipher.final
      @token.unpack("H*").to_s          #makes cipher alpa-numeric pretty
  end
  
  def resolve_token(token, user_id)
    require 'openssl'
    require 'digest/sha2'
    cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
    cipher.decrypt
    cipher.key = AppConfig.first.calendar_feed_hash
      cipher.iv = User.find(user_id).calendar_feed_hash
      @source_string = cipher.update(token.to_a.pack("H*"))    #unpacks cipher and decrpts to original string
      @source_string << cipher.final
      @source = @source_string.split(',')[0].constantize.find(@source_string.split(',')[1])     #gets shift_source from string
      @feed_type=@source_string.split(',')[2]   #is it for Shifts or for Sub_Requests
      return @source, @feed_type
      #This block will fail with bad data -- but it is handled in the grab function.
  end

  def generate_ical
    cal = Icalendar::Calendar.new
    cal.custom_property("METHOD","PUBLISH")
    cal.custom_property("x-wr-calname", @type + "s: " + @source.name)
    cal.custom_property("X-WR-CALDESC", @type + "s Calendar Feed for user: " + @user.name + ".  The feed is " + @source.class.name.downcase + ": " + @source.name)
    cal.custom_property("X-PUBLISHED-TTL", "PT1H")  #default refresh rate
      @shifts.each do |shift|
        @event = Icalendar::Event.new
        @event.dtstart = shift.start.to_s(:us_icaldate)
        @event.dtend = shift.end.to_s(:us_icaldate)
        if @type == "Shift"
          @event.summary = "Shift" + (@source.class.name != "User" ? " for #{shift.user.name}" : "") + " in #{shift.location.short_name}"
          @event.summary << " (sub requested!)" if shift.has_sub?
          @event.description = shift.user.name + " has requested a sub for this shift!"
        elsif @type == "SubRequest"
          @event.description = "\nMandatory: " + shift.mandatory_start.to_s(:twelve_hour) + " - " + shift.mandatory_end.to_s(:twelve_hour) 
          @event.description << "\n\n" + shift.reason
           @event.summary = "Sub for #{shift.user.name} in #{shift.location.short_name}"
        end  
        @event.location = shift.location.name
        cal.add @event
      end
      headers['Content-Type'] = "text/calendar; charset=UTF-8"
      headers['Content-Disposition'] = "inline; filename=" + User.find(params[:user_id]).name + "_calendar_feed.ics"
     # cal.publish  #not necessary...
      cal.to_ical
  end    
  
  
end