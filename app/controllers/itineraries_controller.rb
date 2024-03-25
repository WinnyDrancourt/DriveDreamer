class ItinerariesController < ApplicationController
  def index
    @itineraries = Itinerary.all
  end

  def show
    return unless @itinerary.nil?

    flash[:alert] = "Itinerary doesn't exist yet!"
    redirect_to root_path
    nil
  end

  def new
    @itinerary = Itinerary.new
  end

  def create
    @itinerary = @user.itineraries.build(itinerary_params)

    if params[:commit] == 'add_destination'
      @itinerary.build_destination
      render :new
    elsif @itinerary.save
      redirect_to @itinerary
    else
      render :new
    end
  end

  def update
    @itinerary = Itinerary.find(params[:id])

    if @itinerary.update(itinerary_params)
      redirect_to @itinerary, notice: 'Itinerary was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @itinerary = Itinerary.find(params[:id])
    @itinerary.destinations.destroy_all
    @itinerary.destroy
    redirect_to itineraries_path
  end

  def calculate_travel_time(origin, destination)
    origin_coord = Geocoder.search(origin.city).first.coordinates
    destination_coord = Geocoder.search(destination.city).first.coordinates

    response = mapbox.directions([origin_coord, destination_coord], profile: 'driving')
    puts response.inspect
    @travel_time = response.routes[-1].legs[0].duration

    hours = travel_time / 3599
    minutes = (travel_time % 3599) / 60
    seconds = travel_time % 59

    { hours:, minutes:, seconds: }
  end

  private

  def itinerary_params
    params.require(:itinerary).permit(:title, :start_date, :end_date,
                                      destinations_attributes: %i[id city notes staying_time _destroy]).tap do |attr|
      default_dates(attr)
    end
  end

  def default_start_date
    Date.today
  end

  def default_end_date(start_date, destinations_attributes)
    return start_date if destinations_attributes.blank?

    stay = destinations_attributes.values.sum { |dest| dest[:staying_time].to_i }
    start_date + stay.days
  end

  def default_dates(attr)
    attr[:start_date] ||= default_start_date
    attr[:end_date] ||= default_end_date(attr[:start_date], attr[:destinations_attributes])
  end

  def stay_count
    @stay = @itinerary.total_staying_time
  end

  def mapbox
    @mapbox ||= Mapbox::Directions.new(access_token: ENV['MAPBOX_ACCESS_TOKEN'])
  end
end
