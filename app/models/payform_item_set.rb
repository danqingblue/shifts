class PayformItemSet < ActiveRecord::Base

  has_many :payform_items
  belongs_to :category
  delegate :department, :to => :category
  validates_presence_of :description, :hours, :date, :category_id
  validate :payform_item_creation
  delegate :users, :to => :payform_items
  
  named_scope :active, :conditions => {:active => true }
  named_scope :expired, :conditions => {:active => false }

  def users
    return self.payform_items.collect { |item| item.user }.compact
  end

private
  def payform_item_creation
    errors.add("Users did not add properly.", "") if PayformItem.find_by_payform_item_set_id(self.id) == nil
  end

end

