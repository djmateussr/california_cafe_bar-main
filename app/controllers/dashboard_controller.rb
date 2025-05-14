class DashboardController < ApplicationController
  helper_method :sales
  require 'axlsx'

  def sales
    day_sales
    day_balance
    export_week_sales

    # Agrupando vendas por mês
    sales_by_month = Sale.all.group_by { |sale| sale.created_at.beginning_of_month }

    @sales_totals_by_month = sales_by_month
      .sort_by { |month, _| month }
      .reverse
      .map do |month, sales|
        total_price = sales.sum { |sale| sale.total_price || 0 }
        total_quantity = sales.sum { |sale| sale.quantity || 0 }
        [month, [total_price, total_quantity]]
      end.to_h
  end

  def week_sales
    export_week_sales

    sales_by_week = Sale.all.group_by { |sale| sale.created_at.beginning_of_week }
    @total_sales_by_week = sales_by_week.map do |week, sales|
      total_price = sales.sum { |sale| sale.total_price || 0 }
      total_quantity = sales.sum { |sale| sale.quantity || 0 }
      [week, [total_price, total_quantity]]
    end.to_h
  end

  def day_sales
    @today_sales = Sale.where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)
                       .includes(:stock)
  end

  def export_week_sales
    @week_sales = Sale.where(created_at: Time.zone.now.beginning_of_week..Time.zone.now.end_of_week)
                      .includes(:stock)
  end

  def day_balance
    @today_balance = Sale.where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)
                          .sum(:total_price)
  end

  def day_stock
    @today_sales = Sale.where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)
    @stock_items_sold = @today_sales.group(:stock_id).sum(:quantity)
  end

  def stock
    day_stock
  end

  def compare_months; end

  def details_by_month
    if params[:month].present?
      @sales_details = Sale.where("created_at LIKE ?", "%#{params[:month]}%")

      @payment_methods = @sales_details.group_by(&:payment_method)
      @most_used_payment_method = @payment_methods.max_by { |method, sales| sales.count }
    else
      flash[:error] = "Mês não especificado"
      redirect_to root_path
    end
  end

  def index; end

  def show; end

  # Este método exporta os dados para um arquivo Excel.
  def export_to_excel
    @sales_details = Sale.where("created_at LIKE ?", "%#{params[:month]}%")
    
    package = Axlsx::Package.new
    wb = package.workbook

    wb.add_worksheet(name: 'Vendas') do |sheet|
      sheet.add_row ['Estoque', 'Quantidade', 'Preço Total', 'Data', 'Método de Pagamento']

      @sales_details.each do |sale|
        sheet.add_row [
          sale.stock ? sale.stock.name : 'Produto não encontrado',  # Verificação para garantir que stock não seja nil
          sale.quantity,
          "R$ #{'%.2f' % sale.total_price}",
          sale.created_at.strftime('%d/%m/%Y - %H:%M:%S'),
          sale.payment_method.present? ? sale.payment_method.capitalize : 'Método Desconhecido'
        ]
      end
    end

    send_data package.to_stream.read, filename: "vendas_#{params[:month]}.xlsx", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end
end
  def export
    day_sales
    day_stock
  
    respond_to do |format|
      format.xlsx {
        response.headers['Content-Disposition'] = 'attachment; filename="sales_and_stock_data.xlsx"'
      }
    end
  end


