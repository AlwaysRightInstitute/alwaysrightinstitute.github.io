---
layout: default
title: The Always Right Institute
tags: swift orm database server postgresql swifter
---

<div class="posts">
  {% for post in site.posts %}
    {% if !post.hidden  %}
      <article class="post">
        <h1><a href="{{ site.baseurl }}{{ post.url }}">{{ post.title }}</a></h1>

        <div class="entry">
          {{ post.excerpt }}
        </div>
      
        <div class="date">
          <table border="0" width="100%"> <!-- old skool -->
            <tr>
              <td>{{ post.date | date: "%B %e, %Y" }}</td>
              <td align="right"><a href="{{ site.baseurl }}{{ post.url }}" class="read-more">Read More</a></td>
            </tr>
          </table>
        </div>
      </article>
    {% endif %}
  {% endfor %}
</div>