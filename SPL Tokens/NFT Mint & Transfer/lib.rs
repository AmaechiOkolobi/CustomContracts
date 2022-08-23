use anchor_lang::prelude::*;
use anchor_spl::token;
use anchor_spl::token::{Token, InitializeMint, MintTo, Transfer};

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod spltoken {
    use super::*;

    pub fn mint_token(ctx: Context<MintToken>,) -> Result<()> {
        //MintTo Struct for our Context
        let cpi_accounts = MintTo {
            mint: ctx.accounts.mint.to_account_info(),
            to: ctx.accounts.token_account.to_account_info(),
            authority: ctx.accounts.owner.to_account_info(),
        };

        let cpi_program = ctx.accounts.token_program.to_account_info();

        //CpiContext for request
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

        //Anchor helper function to mint 
        token::mint_to(cpi_ctx, 1)?;
        Ok(())
    }

    pub fn transfer_token(ctx: Context<TransferToken>) -> Result<()> {
        // Create the Transfer struct for our context
        let transfer_instruction = Transfer{
            from: ctx.accounts.from.to_account_info(),
            to: ctx.accounts.to.to_account_info(),
            authority: ctx.accounts.signer.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        // Create the Context for our Transfer request
        let cpi_ctx = CpiContext::new(cpi_program, transfer_instruction);
        // Execute anchor's helper function to transfer tokens
        anchor_spl::token::transfer(cpi_ctx, 1)?;
        
        Ok(())
    }
}

//16.56
#[derive(Accounts)]
pub struct MintToken<'info> {
    /// CHECK: This is not dangerous because we don't read or write from this account
    #[account(mut)]
    pub mint: UncheckedAccount<'info>, //The Token that is being minted
    pub token_program: Program<'info, Token>, //IDL used for front end interaction
    /// CHECK:This is not dangerous because we don't read or write from this account
    #[account(mut)]
    pub token_account: UncheckedAccount< 'info>, //Who the tokens are being minted to
    /// CHECK:This is not dangerous because we don't read or write from this account
    #[account(mut)]
    pub owner: AccountInfo<'info>, //User with mint authority (wallet address)
}
 
#[derive(Accounts)]
pub struct TransferToken<'info> {
    pub token_program: Program<'info, Token>,
    /// CHECK: This is not dangerous because we don't read or write from this account
    #[account(mut)]
    pub from: UncheckedAccount<'info>,
    /// CHECK: This is not dangerous because we don't read or write from this account
    #[account(mut)]
    pub to: AccountInfo<'info>,
    #[account(mut)]
    pub signer: Signer<'info>,
}