class UserProfile < ActiveRecord::Base

  belongs_to :user
  has_many :user_profile_entries
  
  def update(user_profile_entries, user_profile_fields)
    begin
      UserProfile.transaction do
        @failed = []
        user_profile_entries.each do |entry_id, entry_content|
          entry = UserProfileEntry.find(entry_id)
#          if entry == nil
#            entry = UserProfileEntry.new(id = entry_id, content = entry_content, created_at = Time.now, user_profile_id = @user_profile.id, user_profile_field_id = entry_id.field)
#          end
          @content = ""
          if entry.display_type == "check_box"
            UserProfileEntry.find(entry_id).values.split(", ").each do |value|
              c = entry_content[value]
              @content += value + ", " if c == "1"
            end
          @content.gsub!(/, \Z/, "")
          entry.content = @content
          @failed << entry.field_name unless entry.save

          elsif entry.display_type == "radio_button"
            entry.content = entry_content["1"]
            @failed << entry.field_name unless entry.save
          else
            entry.content = entry_content[entry_id]
            @failed << entry.field_name unless entry.save
          end
        end
        user_profile_fields.each do |field_id, field_content|
          entry = UserProfileEntry.new(content = field_content, created_at = Time.now, user_profile_id = @user_profile.id)
          @content = ""
          if entry.display_type == "check_box"
            UserProfileEntry.find(entry_id).values.split(", ").each do |value|
              c = entry_content[value]
              @content += value + ", " if c == "1"
            end
          @content.gsub!(/, \Z/, "")
          entry.content = @content
          @failed << entry.field_name unless entry.save

          elsif entry.display_type == "radio_button"
            entry.content = entry_content["1"]
            @failed << entry.field_name unless entry.save
          else
            entry.content = entry_content[entry_id]
            @failed << entry.field_name unless entry.save
          end
        end
      end
    end
  end
end

