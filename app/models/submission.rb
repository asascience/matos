class Submission < ActiveRecord::Base

  belongs_to :user
  belongs_to :study

  before_destroy :destroy_extracted

  validates_presence_of :user, :study, :datatype

  has_attached_file :datafile
  validates_attachment_presence :datafile

  DATATYPES = %w[recievers tags receptions]

  def DT_RowId
    self.id
  end

  def status=(status)
    write_attribute(:status,status.downcase)
  end

  def process
    if datatype == 'receivers'
      Parse.receivers(self.study.id, self.datafile.path, self.cleardata)
    elsif datatype == 'tags'
      Parse.tags(self.study.id, self.datafile.path, self.cleardata)
    elsif datatype == 'receptions'
      Parse.hits(self.study.id, self.datafile.path, self.cleardata)
    end
  end

end

# ## Schema Information
# Schema version: 20130402164311
#
# Table name: submissions
#
# Field                      | Type               | Attributes
# -------------------------- | ------------------ | -------------------------
# **id                    ** | `integer         ` | `not null, primary key`
# **user_id               ** | `integer         ` | ``
# **status                ** | `string(255)     ` | ``
# **created_at            ** | `datetime        ` | `not null`
# **updated_at            ** | `datetime        ` | `not null`
# **study_id              ** | `integer         ` | ``
# **datatype              ** | `string(255)     ` | ``
# **datafile_file_name    ** | `string(255)     ` | ``
# **datafile_content_type ** | `string(255)     ` | ``
# **datafile_file_size    ** | `integer         ` | ``
# **datafile_updated_at   ** | `datetime        ` | ``
#

