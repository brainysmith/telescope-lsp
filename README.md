# telescope-lsp
LSP extentions for Telescope plugin

##Instalation

Instalation using [packer.nvim][1]: `use 'brainysmith/telescope-lsp'`.

##Usage

Move the cursor to a line with CodeLense and call `:lua require'telescope-lsp'.code_lens(require("telescope.themes").get_dropdown{})`.

[1]: https://github.com/wbthomason/packer.nvim
