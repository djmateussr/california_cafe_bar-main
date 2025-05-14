class Stock < ApplicationRecord
  # Callback to set a default barcode if the item is a "salgado"
  before_save :set_default_barcode, if: :is_salgado?

  # Associations
  belongs_to :user
  has_many :sales
  

  # Validations
  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :amount, :price, presence: true

  # Conditional validation for barcode only if it's not a "salgado"
  validates :barcode, presence: true, uniqueness: true, length: { is: 13 }, unless: :is_salgado?

  private

  # Method to set a default barcode value for "salgados"
  def set_default_barcode
    self.barcode = "1111111111111" # default barcode to all salgados
  end

  # Method to check if the stock is a "salgado"
  def is_salgado?
    self[:is_salgado] == true
  end
end
