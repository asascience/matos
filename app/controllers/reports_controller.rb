class ReportsController < ApplicationController

  layout 'application'

  def index
    authorize! :manage, Report
    if params[:study_id]
      study = Study.find(params[:study_id])
    end
    respond_to do |format|
      format.html {
        # The grid page is really only meant for people that
        # can adminster the study
        if params[:study_id]
          authorize! :manage, study
        else
          authorize! :manage, Study
        end
        render :layout => 'admin'
      }
      format.dataTable {
        columns = params[:sColumns].split(",")
        sort_direction = params[:sSortDir_0]
        sort_column = columns[params[:iSortCol_0].to_i]
        page_num = (params[:iDisplayStart].to_i / params[:iDisplayLength].to_i) + 1
        if params[:study_id]
          authorize! :manage, study
          reports = Report.includes({:tag_deployment => {:tag => :study}}).where(["tag_deployment_id IS NULL OR tags.study_id = ?",study.id]).order("#{sort_column} #{sort_direction}").page(page_num.to_i).per(params[:iDisplayLength].to_i)
        else
          authorize! :manage, Study
          reports = Report.includes({:tag_deployment => :tag}).order("#{sort_column} #{sort_direction}").page(page_num.to_i).per(params[:iDisplayLength].to_i)
        end
        render :json => {
          :sEcho => params[:sEcho],
          :iTotalRecords => reports.total_count,
          :iTotalDisplayRecords => reports.total_count,
          :aaData => reports.as_json({
            :methods => [:DT_RowId],
            :include => { :tag_deployment => {
              :only => [nil],
              :include => {:tag => {
                  :only => :code,
                  :include => {:study => {
                    :only => :name
                  }}
                }
              }
            }}
          })
        }
      }
    end
  end

  def new
    authorize! :create, Report
    @report = Report.new
  end

  def create
    authorize! :create, Report
    @report = Report.new(params[:report])
    @report.found = Date.strptime(params[:report][:found],"%m/%d/%Y").to_date rescue nil
    if params[:report][:input_tag]
      @report.tag_deployment = Tag.find_match(params[:report][:input_tag]).first.active_deployment rescue nil
    elsif params[:report][:input_external_code]
      @report.tag_deployment = TagDeployment.find_match(params[:report][:input_external_code]).first rescue nil
    end
    if @report.save
      ReportMailer.report_invoice(@report).deliver
      if @report.tag_deployment
        ReportMailer.matched_report_notification(@report).deliver
      else
        ReportMailer.unmatched_report_notification(@report).deliver
      end
      respond_to do |format|
        flash["notice"] = "Thank you for submitting a Report!"
        format.html { redirect_to :action => :info }
      end
    else
      respond_to do |format|
        format.html { render :action => :new }
      end
    end
  end

  def destroy
    @report = Report.find(params[:id])
    authorize! :destroy, @report
    @report.destroy
    respond_to do |format|
      format.html
      format.js { render :json => nil, :status => :ok}
    end
  end

  def update
    @report = Report.find(params[:id])
    authorize! :update, @report
    status = @report.update_attributes(params[:report]) ? 200 : 500
    respond_to do |format|
      format.js { render :json => nil, :status => status}
    end
  end

end
