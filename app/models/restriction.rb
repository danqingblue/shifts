class Restriction < ActiveRecord::Base
  belongs_to :department

  validates_presence_of :starts, :expires
  validates_presence_of :max_hours,  :unless => :max_subs, :message => "and Max subs can't both be blank"
  attr_accessor :start_date
  attr_accessor :start_time
  attr_accessor :end_date
  attr_accessor :end_time
  before_validation :join_date_and_time

  named_scope :current, lambda {{ :conditions => ["#{:starts.to_sql_column} <= #{Time.now.to_sql} and #{:expires.to_sql_column} >= #{Time.now.to_sql}"]}}

  def users
    self.user_sources.collect{|s| s.users}.flatten.uniq
  end

  def locations
    self.location_sources.collect{|s| s.locations}.flatten.uniq
  end

  def join_date_and_time
    self.starts ||= self.start_date.to_date.to_time + self.start_time.seconds_since_midnight
    self.expires ||= self.end_date.to_date.to_time + self.end_time.seconds_since_midnight
  end

end

