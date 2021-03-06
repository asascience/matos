class TagDeployment < ActiveRecord::Base
  include PgSearch

  pg_search_scope :search_all,
                  :against =>  [ :common_name,
                                 :scientific_name,
                                 :capture_location,
                                 :external_codes,
                                 :description,
                                 :release_group,
                                 :release_location
                               ],
                  :using => {
                    :tsearch => {:prefix => true},
                    :trigram => {}
                  }

  pg_search_scope :exact_match,
                  :against => [:external_codes, :sensor_codes],
                  :using => {
                    :tsearch => {:any_word => true}
                  }

  belongs_to :tag
  belongs_to :study

  has_one    :report
  has_many   :hits
  has_many   :receiver_deployments, :through => :hits

  validates :tag_id, :release_date, :study_id, :presence => true

  after_create  :set_active_deployment
  after_destroy :set_active_deployment

  scope :readable, lambda {|u| 
    if u.is_admin?
      includes({ :study => {:collaborators => :user}})
    else
      includes({ :study => {:collaborators => :user}}).where("studies.user_id = #{u.id} OR users.id = #{u.id}")
    end
  }
  scope :managable, lambda {|u| 
    if u.is_admin?
      includes({ :study => {:collaborators => :user}})
    else
      includes({ :study => {:collaborators => :user}}).where("studies.user_id = #{u.id} OR ( collaborators.role = 'manage' AND users.id = #{u.id} )")
    end
  }

  set_rgeo_factory_for_column(:capture_geo, RGeo::Geographic.spherical_factory(:srid => 4326))
  set_rgeo_factory_for_column(:surgery_geo, RGeo::Geographic.spherical_factory(:srid => 4326))
  set_rgeo_factory_for_column(:release_geo, RGeo::Geographic.spherical_factory(:srid => 4326))

  def self.find_match(codes)
    TagDeployment.select(:external_codes).each do |ext|
      # If the intersection is not empty, we matched one...
      if !(ext.external_codes & codes).empty?
        return ext
        break
      end
    end
    return nil
  end

  def sensor_codes
    ec = read_attribute(:sensor_codes)
    if ec.blank?
      return nil
    else
      return ec.split(",") rescue nil
    end
  end

  def sensor_codes=(codes)
    if codes.blank?
      write_attribute(:sensor_codes, nil)
    elsif codes.is_a? String
      write_attribute(:sensor_codes, codes)
    elsif codes.is_a? Array
      write_attribute(:sensor_codes, codes.join(","))
    end
  end

  def external_codes
    ec = read_attribute(:external_codes)
    if ec.blank?
      return nil
    else
      return ec.split(",") rescue nil
    end
  end

  def external_codes=(codes)
    if codes.blank?
      write_attribute(:external_codes, nil)
    elsif codes.is_a? String
      write_attribute(:external_codes, codes)
    elsif codes.is_a? Array
      write_attribute(:external_codes, codes.join(","))
    end
  end

  def geojson   
    features = []

    self.hits.each do |h|
      s = {}
      s[:time] = h.time
      s[:depth] = h.depth
      s[:receiver_deployment] = h.receiver_deployment.geo_attributes

      features << RGeo::GeoJSON::Feature.new(h.location, h.id, s)
    end

    fc = RGeo::GeoJSON::FeatureCollection.new(features)
    return RGeo::GeoJSON.encode(fc) 

  end

  def starting
    release_date
  end

  def ending
    report.nil? ? nil : report.found
  end

  def common_name=(common_name)
    write_attribute(:common_name,(common_name.downcase rescue nil))
  end

  def scientific_name=(scientific_name)
    write_attribute(:scientific_name,(scientific_name.downcase rescue nil))
  end

  def implant_type=(implant_type)
    write_attribute(:implant_type,(implant_type.downcase rescue nil))
  end

  def display_name
    z = tag.to_label
    z += " - #{starting.strftime('%Y-%m-%d')}"
    z += "/#{ending.strftime('%Y-%m-%d')}" unless ending.nil?
    z
  end

  def date_range
    z = ""
    z += "#{starting.strftime('%Y-%m-%d')}"
    z += "/#{ending.strftime('%Y-%m-%d')}" unless ending.nil?
    z += "No date information available" if z.blank?
    z
  end

  def display_attributes
    remove_attrs = [:study_id, :id, :tag_id]
    self.attributes.delete_if { |k,v| remove_attrs.include?(k.to_sym) }
  end

  private
    def set_active_deployment
      self.tag.active_deployment = TagDeployment.includes(:tag).where(:tag_id => self.tag.id).order("release_date DESC").limit(1).first rescue nil
      self.tag.save!
    end
end

# ## Schema Information
# Schema version: 20130311180440
#
# Table name: tag_deployments
#
# Field                                          | Type               | Attributes
# ---------------------------------------------- | ------------------ | -------------------------
# **id                                        ** | `integer         ` | `not null, primary key`
# **tag_id                                    ** | `integer         ` | ``
# **tagger                                    ** | `string(255)     ` | ``
# **common_name                               ** | `string(255)     ` | ``
# **scientific_name                           ** | `string(255)     ` | ``
# **capture_location                          ** | `string(255)     ` | ``
# **capture_geo                               ** | `spatial({:srid=>` | ``
# **capture_date                              ** | `datetime        ` | ``
# **capture_depth                             ** | `decimal(6, 2)   ` | ``
# **wild_or_hatchery                          ** | `string(255)     ` | ``
# **stock                                     ** | `string(255)     ` | ``
# **length                                    ** | `decimal(6, 2)   ` | ``
# **weight                                    ** | `decimal(6, 2)   ` | ``
# **age                                       ** | `string(255)     ` | ``
# **sex                                       ** | `string(255)     ` | ``
# **dna_sample_taken                          ** | `boolean         ` | ``
# **treatment_type                            ** | `string(255)     ` | ``
# **temperature_change                        ** | `decimal(4, 2)   ` | ``
# **holding_temperature                       ** | `decimal(4, 2)   ` | ``
# **surgery_location                          ** | `string(255)     ` | ``
# **surgery_geo                               ** | `spatial({:srid=>` | ``
# **surgery_date                              ** | `datetime        ` | ``
# **sedative                                  ** | `string(255)     ` | ``
# **sedative_concentration                    ** | `string(255)     ` | ``
# **anaesthetic                               ** | `string(255)     ` | ``
# **buffer                                    ** | `string(255)     ` | ``
# **anaesthetic_concentration                 ** | `string(255)     ` | ``
# **buffer_concentration_in_anaesthetic       ** | `string(255)     ` | ``
# **anesthetic_concentration_in_recirculation ** | `string(255)     ` | ``
# **buffer_concentration_in_recirculation     ** | `string(255)     ` | ``
# **do                                        ** | `decimal(6, 1)   ` | ``
# **description                               ** | `text            ` | ``
# **release_group                             ** | `string(255)     ` | ``
# **release_location                          ** | `string(255)     ` | ``
# **release_geo                               ** | `spatial({:srid=>` | ``
# **release_date                              ** | `datetime        ` | ``
# **external_codes                            ** | `string(255)     ` | ``
# **length_type                               ** | `string(255)     ` | ``
# **implant_type                              ** | `string(255)     ` | ``
# **reward                                    ** | `string(255)     ` | ``
# **study_id                                  ** | `integer         ` | ``
# **sensor_codes                              ** | `string(255)     ` | ``
#
# Indexes
#
#  index_tag_deployments_on_capture_geo  (capture_geo)
#  index_tag_deployments_on_release_geo  (release_geo)
#  index_tag_deployments_on_surgery_geo  (surgery_geo)
#  index_tag_deployments_on_tag_id       (tag_id)
#

