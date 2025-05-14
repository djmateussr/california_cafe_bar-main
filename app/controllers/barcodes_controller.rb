class BarcodesController < ApplicationController

  # Inicia o processo de venda, limpando a sessão de produtos
  def start_selling
    session[:stocks] = []
    redirect_to barcodes_scan_path
  end

  # Busca o produto pelo código de barras e o adiciona ao carrinho de compras
  def search
    barcode = params[:barcode]
    stock = Stock.find_by(barcode: barcode)

    if stock
      session[:stocks] ||= []
      session[:stocks] << stock
      flash[:notice] = "Produto adicionado ao carrinho!"
    else
      flash[:alert] = "Produto não encontrado!"
    end

    redirect_to barcodes_scan_path
  end

  # Finaliza a venda, criando um registro de venda e atualizando o estoque
  def finish_sale
    payment_method = params[:payment_method]

    # Verifica se o método de pagamento foi informado
    unless payment_method.present?
      flash[:alert] = "Método de pagamento não selecionado!"
      return redirect_to barcodes_scan_path
    end

    # Realiza a transação para garantir que todas as operações sejam atômicas
    Sale.transaction do
      session[:stocks].each_with_index do |stock_data, index|
        stock_info = stock_data.is_a?(Array) ? stock_data.last : stock_data
        stock = Stock.find(stock_info['id'])

        # Atualiza o estoque de acordo com o item selecionado
        if stock.barcode == '1111111111111' && params[:stocks] && params[:stocks][index.to_s]
          salgado_type_id = params[:stocks][index.to_s][:salgado_type]
          stock = Stock.find(salgado_type_id)
        end

        if stock.amount > 0
          sale = Sale.new(stock: stock, quantity: 1, payment_method: payment_method)

          if sale.save
            # Reduz a quantidade do estoque após a venda
            stock.update!(amount: stock.amount - 1)
            puts "Venda criada com sucesso!"
          else
            flash[:alert] = "Falha ao criar a venda: #{sale.errors.full_messages.join(", ")}"
            raise ActiveRecord::Rollback, "Venda não realizada"
          end
        else
          flash[:alert] = "Estoque insuficiente para o produto #{stock.name}"
          raise ActiveRecord::Rollback, "Estoque insuficiente"
        end
      end
    end

    session[:stocks] = []
    redirect_to barcodes_scan_path, notice: 'Venda finalizada com sucesso!'
  rescue ActiveRecord::Rollback => e
    flash[:alert] = "Erro na transação: #{e.message}"
    redirect_to barcodes_scan_path
  end

  # Cancela a venda, limpando a sessão de produtos
  def cancel_sale
    session[:stocks] = []
    redirect_to barcodes_scan_path, notice: 'Venda cancelada com sucesso!'
  end
end