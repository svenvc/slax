const RoomMessages = {
    mounted() {
      this.el.scrollTop = this.el.scrollHeight;

      this.handleEvent("scroll_messages_to_bottom", () => {
        this.el.scrollTop = this.el.scrollHeight;
      });

      this.canLoadMore = true;

      this.el.addEventListener("scroll", e => {
        if (this.canLoadMore && this.el.scrollTop < 100) {
          this.canLoadMore = false;
          const prevHeight = this.el.scrollHeight;

          this.pushEvent("load-more-messages", {}, (reply) => {
            this.el.scrollTo(0, this.el.scrollHeight - prevHeight);
            this.canLoadMore = reply.can_load_more;;
          });
        }
      })

      this.handleEvent("reset_pagination", ({can_load_more}) => {
        this.canLoadMore = can_load_more;
      });

      this.handleEvent("update_avatar", ({user_id, avatar_path}) => {
        const avatars = this.el.querySelectorAll(`img[data-user-avatar-id="${user_id}"]`);

        avatars.forEach(function(avatar) {
          avatar.src = `/uploads/${avatar_path}`;
        });
      });
    }
  };
  
  export default RoomMessages;