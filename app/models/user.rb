class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable, :token_authenticatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :name, :email, :organization, :password, :password_confirmation, :remember_me, :role, :requested_role, :approved, :newsletter, :address, :city, :state, :zipcode, :phone

  ROLES = %w[guest general researcher investigator admin]
  REGISTERABLE_ROLES = ROLES - %w[guest admin]
  ROLE_MAP = {
    :guest => "Unregistered visitor to the site",
    :general => "Registered user of the MATOS website",
    :researcher => "Researcher interested in MATOS data",
    :investigator => "Contributor to the MATOS database",
    :admin => "Administrator of the MATOS website"
  }

  validates_presence_of :name, :email
  validates_uniqueness_of :name, :email, :case_sensitive => false
  validates :email, :format => { :with => /^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i, :message => "invalid email address" }
  validates :role, :if => "approved == true", :inclusion => { :in => ROLES, :message => "%{value} is not a valid role" }

  has_many :studies

  def is_admin?
    self.role == "admin"
  end

  def DT_RowId
    self.id
  end

  def approve!
    self.approved = true
    self.save!
  end

  # Accounts need to be approved
  def active_for_authentication?
    super && approved?
  end

  def self.send_reset_password_instructions(attributes={})
    recoverable = find_or_initialize_with_errors(reset_password_keys, attributes, :not_found)
    if !recoverable.approved? && recoverable.errors.blank?
      recoverable.errors[:base] << I18n.t("devise.failure.not_approved")
    elsif recoverable.persisted?
      recoverable.send_reset_password_instructions
    end
    recoverable
  end

end

# ## Schema Information
# Schema version: 20130311180440
#
# Table name: users
#
# Field                       | Type               | Attributes
# --------------------------- | ------------------ | -------------------------
# **id                     ** | `integer         ` | `not null, primary key`
# **email                  ** | `string(255)     ` | `default(""), not null`
# **encrypted_password     ** | `string(255)     ` | `default(""), not null`
# **reset_password_token   ** | `string(255)     ` | ``
# **reset_password_sent_at ** | `datetime        ` | ``
# **remember_created_at    ** | `datetime        ` | ``
# **sign_in_count          ** | `integer         ` | `default(0)`
# **current_sign_in_at     ** | `datetime        ` | ``
# **last_sign_in_at        ** | `datetime        ` | ``
# **current_sign_in_ip     ** | `string(255)     ` | ``
# **last_sign_in_ip        ** | `string(255)     ` | ``
# **confirmation_token     ** | `string(255)     ` | ``
# **confirmed_at           ** | `datetime        ` | ``
# **confirmation_sent_at   ** | `datetime        ` | ``
# **created_at             ** | `datetime        ` | `not null`
# **updated_at             ** | `datetime        ` | `not null`
# **role                   ** | `string(255)     ` | ``
# **approved               ** | `boolean         ` | `default(FALSE), not null`
# **name                   ** | `string(255)     ` | ``
# **organization           ** | `string(255)     ` | ``
# **requested_role         ** | `string(255)     ` | ``
# **address                ** | `string(255)     ` | ``
# **city                   ** | `string(255)     ` | ``
# **state                  ** | `string(255)     ` | ``
# **zipcode                ** | `string(8)       ` | ``
# **phone                  ** | `string(255)     ` | ``
# **newsletter             ** | `boolean         ` | `default(FALSE)`
# **authentication_token   ** | `string(255)     ` | ``
#
# Indexes
#
#  index_users_on_approved              (approved)
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#

