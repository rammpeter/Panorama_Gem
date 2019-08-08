# encoding: utf-8
module DbaSchemaHelper

  def explain_calc_free_space_by_avg_row_len
    "
Calculated by size of all allocated extents - (Avg_Row_Len*Num_Rows) considering also block header, PCT_FREE, INI_TRANS.

May be inaccurate due to partial analyze with estimated average row length or object compression.\nFor exact values click for calculation with DBMS_SPACE.SPACE_USAGE."
  end

  def calc_free_space_pct_by_avg_row_len(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb)
    calc_free_space_mb_by_avg_row_len(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb) * 100.0 / size_mb rescue nil
  end

  def calc_free_space_mb_by_avg_row_len(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb)
    return nil if avg_row_len.nil? || num_rows.nil? || pct_free.nil? || ini_trans.nil? || size_mb.nil?
    data_size_per_block_without_row_dir =
        blocksize -
        57 -                                                                    # Block header size
        4 -                                                                     # table directory = 4*number of tables (usually 1 unless you're using clusters)
        ini_trans * 23 -                                                        # transaction list
        blocksize * pct_free/100.0                                              # pct_free

    data_size_per_block =
        data_size_per_block_without_row_dir -
            2 * (data_size_per_block_without_row_dir / avg_row_len).to_i        # row directory

    rows_per_block = (data_size_per_block / avg_row_len).to_i                   # Assuming the last partial row does not fit into the block

    needed_blocks     = (num_rows / rows_per_block).to_i + 1

    size_mb - (needed_blocks * blocksize) / (1024 * 1024)
  rescue
    nil
  end

end