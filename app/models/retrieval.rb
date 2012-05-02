class Retrieval < ActiveRecord::Base

  belongs_to :deployment

  validates :deployment_id, :presence => true

  set_rgeo_factory_for_column(:location, RGeo::Geographic.spherical_factory(:srid => 4326))

  def geo
    return RGeo::GeoJSON.encode(self.location)
  end

  def geojson
    removals = ["location","id","deployment_id"]
    s = self.attributes.delete_if {|key, value| removals.include?(key) }
    feat = RGeo::GeoJSON::Feature.new(self.location, self.id, s)
    RGeo::GeoJSON.encode(feat)
  end

  def latitude(round=3)
    location.latitude.round(round)
  end

  def longitude(round=3)
    location.longitude.round(round)
  end

  def self.load_data(file)
    require 'csv'
    rets = []
    errors = []
    CSV.foreach(file, {:headers => true}) do |row|
      begin
        otna = OtnArray.find_by_code(row["GLATOS_ARRAY"])
        unless otna
          errors << "Error loading Retrieval - No OtnArray with the code #{row["GLATOS_ARRAY"]} - Data: #{row}"
          next
        end
        dep = Deployment.find_by_otn_array_id_and_station_and_consecutive(otna.id, row["STATION_NO"].to_i, row["CONSECUTIVE_DEPLOY_NO"].to_i)
        unless dep
          errors << "Error loading Retrieval - No Deployment found for STATION_NO #{row["STATION_NO"]} and CONSECUTIVE_DEPLOY_NO #{row["CONSECUTIVE_DEPLOY_NO"]} - Data: #{row}"
          next
        end
        ret = Retrieval.find_or_initialize_by_deployment_id(dep.id)
        ret.attributes =
          {
            :data_downloaded => row["DATA_DOWNLOADED"],
            :ar_confirm => row["AR_CONFIRM"],
            :recovered => Time.parse(row["RECOVER_DATE_TIME"] + " UTC"),
            :location => "POINT(#{row['RECOVER_LONG']} #{row['RECOVER_LAT']})"
          }
        if ret.valid?
          rets << ret
        else
          errors << "#{ret.errors.full_messages.join(" and ")} - Data: #{row}"
        end
      rescue
        errors << "Error loading Retrieval - Data: #{row}"
      end
    end
    return rets, errors
  end

end
#
# == Schema Information
#
# Table name: retrievals
#
#  id              :integer         not null, primary key
#  deployment_id   :integer         indexed
#  data_downloaded :boolean
#  ar_confirm      :boolean
#  recovered       :datetime
#  location        :spatial({:srid= indexed
#
